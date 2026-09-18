terraform {
  # NOTE: I couldn't careless which version of terraform or tofu is being used. YOLO!!!
  required_version = ">= 1.0.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.112.0"
    }
  }

  backend "s3" {
    bucket = "letussenghomelab"
    key    = "infra/tf/proxmox/osimages/terraform.state"
  }
}

provider "proxmox" {
  insecure = true

  ssh {
    agent = false
  }
}
