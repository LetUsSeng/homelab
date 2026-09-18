locals {
  pve_nodes = [
    "pve-0", # HP Z440
    "pve-1", # HP Elitedesk
    "pve-2", # HP Elitedesk
  ]

  # see gitops/influxdb/values.yaml
  influxdb_host   = "influxdb.letusseng.com"
  influxdb_org    = "homelab"
  influxdb_bucket = "proxmox"
}
