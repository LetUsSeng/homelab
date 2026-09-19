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

data "influxdb_bucket" "proxmox" {
  name = local.influxdb_bucket
}

# write-only, and only to the proxmox bucket
resource "influxdb_authorization" "proxmox" {
  org_id      = data.influxdb_organization.homelab.id
  description = "proxmox metric server"

  permissions = [
    {
      action = "write"
      resource = {
        type   = "buckets"
        id     = data.influxdb_bucket.proxmox.id
        org_id = data.influxdb_organization.homelab.id
      }
    },
  ]
}

# NOTE:
# letusseng.com only exists in pihole, so the nodes need it to reach influxdb. Pihole runs in k8s on
# these same nodes, so comcast stays as the fallback: glibc moves on when pihole times out, which
# keeps public dns (and apt, ntp, ...) working while the cluster is down.
resource "proxmox_virtual_environment_dns" "pve" {
  for_each = toset(local.pve_nodes)

  node_name = each.key
  domain    = "homelab.local"
  servers = [
    "10.0.0.101", # pihole, see gitops/pihole
    "75.75.75.75",
  ]
}

# Datacenter > Metric Server, cluster-wide so it covers every pve node
resource "proxmox_metrics_server" "influxdb" {
  name   = "homelab"
  type   = "influxdb"
  server = local.influxdb_host
  # traefik ingress, serving the *.letusseng.com letsencrypt cert
  port                = 443
  influx_db_proto     = "https"
  influx_verify       = true
  influx_organization = local.influxdb_org
  influx_bucket       = local.influxdb_bucket
  influx_token        = influxdb_authorization.proxmox.token

  # pve checks the connection on create
  depends_on = [proxmox_virtual_environment_dns.pve]
}
