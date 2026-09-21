terraform {
  required_version = ">= 1.0.0"
  required_providers {
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
    key     = "infra/tf/home-assistant/terraform.state"
    profile = "homelab"
    region  = "us-east-2"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "admin@letusseng-cluster"
}

# admin token only mints the scoped token below; home assistant never sees it
provider "influxdb" {
  url   = "https://${local.influxdb_host}"
  token = data.kubernetes_secret_v1.influxdb_auth.data["admin-token"]
}
