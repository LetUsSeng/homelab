# created by scripts/bootstrap/bootstrap-monitoring-secrets.sh, kept in sync from infisical
# (gitops/influxdb/manifests/infisical-secret.yaml)
data "kubernetes_secret_v1" "influxdb_auth" {
  metadata {
    name      = "influxdb-auth"
    namespace = "monitoring"
  }
}

data "influxdb_organization" "homelab" {
  name = local.influxdb_org
}

# long-term history; the recorder in postgres only keeps purge_keep_days
resource "influxdb_bucket" "home_assistant" {
  org_id           = data.influxdb_organization.homelab.id
  name             = "home-assistant"
  description      = "home assistant state history"
  retention_period = 0 # forever
}

# write-only, and only to the home-assistant bucket
resource "influxdb_authorization" "home_assistant" {
  org_id      = data.influxdb_organization.homelab.id
  description = "home assistant"

  permissions = [
    {
      action = "write"
      resource = {
        type   = "buckets"
        id     = influxdb_bucket.home_assistant.id
        org_id = data.influxdb_organization.homelab.id
      }
    },
  ]
}

# NOTE:
# Nothing mounts this. The influxdb integration is configured once in the home assistant ui,
# which stores the token in .storage; this is where to copy it from (see gitops/home-assistant/README.md).
# The namespace comes from the home-assistant argo app, so sync that first.
resource "kubernetes_secret_v1" "influxdb_token" {
  metadata {
    name      = "influxdb-token"
    namespace = local.namespace
  }

  data = {
    token = influxdb_authorization.home_assistant.token
  }
}
