locals {
  agent_defaults = {
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
    gateway = "10.0.0.1"
    tags    = ["terraform", "ubuntu", "k3s", "agent"]
  }


  agents = {
    agent_0 = {
      name        = "k3s-agent-0"
      vm_id       = 110
      description = "k3s agent"
      node_name   = "pve-0"
      startup = {
        order      = "3"
        up_delay   = "60"
        down_delay = "60"
      }
      cpu = {
        cores = 6
      }
      memory = {
        dedicated = 8192
        floating  = 8192
      }
      disk = {
        datastore_id = "local-lvm"
        file_id      = "local:iso/noble-server-cloudimg-amd64.img"
        interface    = "scsi0"
        size         = 250
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.25/24"
        }
      }
    }

    agent_1 = {
      name        = "k3s-agent-1"
      vm_id       = 111
      description = "k3s agent"
      node_name   = "pve-1"
      startup = {
        order      = "3"
        up_delay   = "60"
        down_delay = "60"
      }
      cpu = {
        cores = 6
      }
      memory = {
        dedicated = 24576
        floating  = 24576
      }
      disk = {
        datastore_id = "local-lvm"
        file_id      = "local:iso/noble-server-cloudimg-amd64.img"
        interface    = "scsi0"
        size         = 140
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.26/24"
        }
      }
    }

    agent_2 = {
      name        = "k3s-agent-2"
      vm_id       = 112
      description = "k3s agent"
      node_name   = "pve-2"
      startup = {
        order      = "3"
        up_delay   = "60"
        down_delay = "60"
      }
      cpu = {
        cores = 6
      }
      memory = {
        dedicated = 8192
        floating  = 8192
      }
      disk = {
        datastore_id = "local-lvm"
        file_id      = "local:iso/noble-server-cloudimg-amd64.img"
        interface    = "scsi0"
        size         = 140
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.27/24"
        }
      }
    }
  }

}

resource "proxmox_virtual_environment_vm" "agent" {
  for_each = local.agents

  name        = each.value.name
  vm_id       = each.value.vm_id
  description = each.value.description
  tags        = local.agent_defaults.tags

  node_name = each.value.node_name

  agent {
    enabled = local.agent_defaults.agent.enabled
  }

  stop_on_destroy = local.agent_defaults.stop_on_destroy

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
        gateway = try(local.agent_defaults.gateway, each.value.ip_config.ipv4.gateway, null)
      }
    }
    user_account {
      # TODO: Probably wrap these in a try but I'm too lazy to do it
      keys     = local.agent_defaults.user_account.keys
      username = local.agent_defaults.user_account.username
    }
  }

  network_device {
    bridge = local.agent_defaults.network_device.bridge
  }

  operating_system {
    type = local.agent_defaults.operating_system.type
  }

}
