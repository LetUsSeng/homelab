# written by the autoBootstrap job in gitops/infisical/values.yaml
data "kubernetes_secret_v1" "infisical_bootstrap" {
  metadata {
    name      = "infisical-bootstrap-secret"
    namespace = "infisical"
  }
}

# infisical calls the api server in-cluster, and needs its ca for that
data "kubernetes_config_map_v1" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = local.operator_namespace
  }
}

# NOTE:
# Only the structure lives here. Secret values are entered in the ui (or `infisical secrets set`),
# so they never end up in the s3 state.
resource "infisical_project" "homelab" {
  name = "homelab"
  slug = local.project_slug
}

resource "infisical_secret_folder" "namespace" {
  for_each = local.folders

  project_id       = infisical_project.homelab.id
  environment_slug = local.environment
  folder_path      = "/"
  name             = each.key
}

resource "infisical_secret_folder" "app" {
  for_each = {
    for pair in flatten([
      for ns, apps in local.folders : [for app in apps : { ns = ns, app = app }]
    ]) : "${pair.ns}/${pair.app}" => pair
  }

  project_id       = infisical_project.homelab.id
  environment_slug = local.environment
  folder_path      = infisical_secret_folder.namespace[each.value.ns].path
  name             = each.value.app
}

# what the secrets operator logs in as
resource "infisical_identity" "k8s_operator" {
  name   = "k8s-operator"
  role   = "no-access"
  org_id = data.kubernetes_secret_v1.infisical_bootstrap.data["organization-id"]
}

resource "infisical_identity_kubernetes_auth" "k8s_operator" {
  identity_id               = infisical_identity.k8s_operator.id
  kubernetes_host           = "https://kubernetes.default.svc"
  kubernetes_ca_certificate = data.kubernetes_config_map_v1.kube_root_ca.data["ca.crt"]

  # no token_reviewer_jwt: infisical reviews the client's own token, which is why the service
  # account is bound to system:auth-delegator
  token_reviewer_mode           = "api"
  allowed_namespaces            = [local.operator_namespace]
  allowed_service_account_names = [local.operator_service_account]

  # the operator logs in again whenever its token runs out
  access_token_ttl     = 3600
  access_token_max_ttl = 86400
}

# read-only on the whole project
resource "infisical_project_identity" "k8s_operator" {
  project_id  = infisical_project.homelab.id
  identity_id = infisical_identity.k8s_operator.id
  roles = [
    {
      role_slug = "viewer"
    },
  ]
}
