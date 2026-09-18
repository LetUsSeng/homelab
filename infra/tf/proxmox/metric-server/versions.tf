terraform {
  # NOTE: I couldn't careless which version of terraform or tofu is being used. YOLO!!!
  required_version = ">= 1.0.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.112.0"
    }
    influxdb = {
      source  = "komminarlabs/influxdb"
      version = "1.4.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
  }

  backend "s3" {
    bucket  = "letussenghomelab"
    key     = "infra/tf/proxmox/metric-server/terraform.state"
    profile = "homelab"
    region  = "us-east-2"
  }
}

# endpoint and credentials come from PROXMOX_VE_* env vars, like the other proxmox roots.
# no ssh block: metric servers are managed purely through the api.
provider "proxmox" {
  insecure = true
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "admin@letusseng-cluster"
}

# admin token only mints the scoped token below; proxmox never sees it
provider "influxdb" {
  url   = "https://${local.influxdb_host}"
  token = data.kubernetes_secret_v1.influxdb_auth.data["admin-token"]
}
