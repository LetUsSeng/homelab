# NOTE: Maybe don't make this look sexy because you hate this type of code.
locals {
  server_defaults = {
    agent = {
      enabled = false
    }
    stop_on_destroy = true
    user_account = {
      keys     = local.ssh_keys
      username = "ubuntu"
    }
    network_device = {
      bridge = "vmbr0"
    }
    operating_system = {
      type = "l26"
    }
    gateway = "10.0.0.1" # NOTE: Probably should be in the locals.tf file
    tags    = ["terraform", "ubuntu", "k3s", "server"]
  }

  servers = {
    server_0 = {
      name        = "k3s-server-0"
      vm_id       = 100
      description = "k3s server"
      node_name   = "pve-0"
      startup = {
        order      = "3"
        up_delay   = "60"
        down_delay = "60"
      }
      cpu = {
        cores = 2
      }
      memory = {
        dedicated = 6144
        floating  = 6144 # set equal to dedicated to enable ballooning
      }
      disk = {
        datastore_id = "local-lvm"
        file_id      = "local:iso/noble-server-cloudimg-amd64.img"
        interface    = "scsi0"
        size         = 50
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.24/24"
        }
      }
    }

    server_1 = {
      name        = "k3s-server-1"
      vm_id       = 101
      description = "k3s server"
      node_name   = "pve-1"
      startup = {
        order      = "3"
        up_delay   = "60"
        down_delay = "60"
      }
      cpu = {
        cores = 2
      }
      memory = {
        dedicated = 6144
        floating  = 6144 # set equal to dedicated to enable ballooning
      }
      disk = {
        datastore_id = "local-lvm"
        file_id      = "local:iso/noble-server-cloudimg-amd64.img"
        interface    = "scsi0"
        size         = 25
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.28/24"
        }
      }
    }

    server_2 = {
      name        = "k3s-server-2"
      vm_id       = 102
      description = "k3s server"
      node_name   = "pve-2"
      startup = {
        order      = "3"
        up_delay   = "60"
        down_delay = "60"
      }
      cpu = {
        cores = 2
      }
      memory = {
        dedicated = 6144
        floating  = 6144 # set equal to dedicated to enable ballooning
      }
      disk = {
        datastore_id = "local-lvm"
        file_id      = "local:iso/noble-server-cloudimg-amd64.img"
        interface    = "scsi0"
        size         = 25
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.29/24"
        }
      }
    }
  }
}

resource "proxmox_virtual_environment_vm" "server" {
  for_each = local.servers

  name        = each.value.name
  vm_id       = each.value.vm_id
  description = each.value.description
  tags        = local.server_defaults.tags

  node_name = each.value.node_name

  agent {
    enabled = local.server_defaults.agent.enabled
  }

  stop_on_destroy = local.server_defaults.stop_on_destroy

  startup {
    order      = each.value.startup.order
    up_delay   = each.value.startup.up_delay
    down_delay = each.value.startup.down_delay
  }

  cpu {
    cores = each.value.cpu.cores
  }

  memory {
    dedicated = each.value.memory.dedicated
    floating  = each.value.memory.floating
  }

  disk {
    datastore_id = each.value.disk.datastore_id
    file_id      = each.value.disk.file_id
    interface    = each.value.disk.interface
    size         = each.value.disk.size
  }

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip_config.ipv4.address
        gateway = try(local.server_defaults.gateway, each.value.ip_config.ipv4.gateway, null)
      }
    }
    user_account {
      # TODO: Probably wrap these in a try but I'm too lazy to do it
      keys     = local.server_defaults.user_account.keys
      username = local.server_defaults.user_account.username
    }
  }

  network_device {
    bridge = local.server_defaults.network_device.bridge
  }

  operating_system {
    type = local.server_defaults.operating_system.type
  }

}
