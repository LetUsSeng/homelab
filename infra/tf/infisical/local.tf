locals {
  # see gitops/infisical/values.yaml
  infisical_host = "infisical.letusseng.com"

  # see gitops/infisical-operator/manifests/auth-serviceaccount.yaml
  operator_namespace       = "infisical-operator-system"
  operator_service_account = "infisical-auth"

  # read by InfisicalSecrets as projectSlug / envSlug
  project_slug = "homelab"
  environment  = "prod"

  # one folder per consuming namespace, one subfolder per app: /<namespace>/<app>
  folders = {
    monitoring = ["grafana"]
  }
}
