terraform {
  # NOTE: I couldn't careless which version of terraform or tofu is being used. YOLO!!!
  required_version = ">= 1.0.0"
  required_providers {
    infisical = {
      source  = "Infisical/infisical"
      version = "0.19.32"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
  }

  backend "s3" {
    bucket  = "letussenghomelab"
    key     = "infra/tf/infisical/terraform.state"
    profile = "homelab"
    region  = "us-east-2"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "admin@letusseng-cluster"
}

# instance-admin identity token, minted by the chart's autoBootstrap job
provider "infisical" {
  host = "https://${local.infisical_host}"
  auth = {
    token = data.kubernetes_secret_v1.infisical_bootstrap.data["token"]
  }
}
