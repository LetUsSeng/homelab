terraform {
  # NOTE: I couldn't careless which version of terraform or tofu is being used. YOLO!!!
  required_version = ">= 1.0.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.72.0"
    }
  }

  backend "s3" {
    bucket = "letusenghomelab"
    key    = "infra/tf/k3s/terraform.state"
  }
}

provider "proxmox" {
  insecure = true

  ssh {
    agent = false
  }
}
