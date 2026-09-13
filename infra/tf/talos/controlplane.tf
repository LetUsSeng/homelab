locals {
  control_plane_defaults = {
    agent = {
      enabled = true
    }
    stop_on_destroy = true
    network_device = {
      bridge = "vmbr0"
    }
    operating_system = {
      type = "l26"
    }
    gateway = "10.0.0.1"
    tags    = ["control-plane", "talos", "terraform"]
  }

  control_planes = {
    control_plane_0 = {
      name        = "talos-control-plane-0"
      vm_id       = 100
      description = "talos control plane"
      node_name   = "pve-0"
      startup = {
        order      = "3"
        up_delay   = "60"
        down_delay = "60"
      }
      cpu = {
        cores = 4
      }
      memory = {
        dedicated = 7450
        floating  = 7450 # set equal to dedicated to enable ballooning
      }
      disk = {
        datastore_id = "local-lvm"
        interface    = "scsi0"
        size         = 200
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.24"
        }
      }
    }

    control_plane_1 = {
      name        = "talos-control-plane-1"
      vm_id       = 101
      description = "talos control plane"
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
        dedicated = 22351
        floating  = 22351 # set equal to dedicated to enable ballooning
      }
      disk = {
        datastore_id = "local-lvm"
        interface    = "scsi0"
        size         = 200
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.28"
        }
      }
    }

    control_plane_2 = {
      name        = "talos-control-plane-2"
      vm_id       = 102
      description = "talos control plane"
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
        dedicated = 11175
        floating  = 11175 # set equal to dedicated to enable ballooning
      }
      disk = {
        datastore_id = "local-lvm"
        interface    = "scsi0"
        size         = 200
      }
      ip_config = {
        ipv4 = {
          address = "10.0.0.29"
        }
      }
    }
  }
}

resource "proxmox_virtual_environment_vm" "control_plane" {
  for_each = local.control_planes

  name        = each.value.name
  vm_id       = each.value.vm_id
  description = each.value.description
  tags        = local.control_plane_defaults.tags

  node_name = each.value.node_name

  agent {
    enabled = local.control_plane_defaults.agent.enabled
  }

  stop_on_destroy = local.control_plane_defaults.stop_on_destroy

  startup {
    order      = each.value.startup.order
    up_delay   = each.value.startup.up_delay
    down_delay = each.value.startup.down_delay
  }

  bios = "ovmf"

  cpu {
    cores = each.value.cpu.cores
    type  = "x86-64-v2-AES"
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  memory {
    dedicated = each.value.memory.dedicated
    floating  = each.value.memory.floating
  }

  disk {
    datastore_id = each.value.disk.datastore_id
    file_id      = proxmox_download_file.talos_image_1_14_0[each.key].id
    interface    = each.value.disk.interface
    size         = each.value.disk.size

    file_format = "raw"

    cache = "writethrough"

  }

  machine = "q35"


  initialization {
    user_data_file_id = proxmox_virtual_environment_file.control_plane_config[each.key].id

    ip_config {
      ipv4 {
        address = "${each.value.ip_config.ipv4.address}/24"
        gateway = try(local.control_plane_defaults.gateway, each.value.ip_config.ipv4.gateway, null)
      }
    }
  }

  network_device {
    bridge = local.control_plane_defaults.network_device.bridge
  }

  operating_system {
    type = local.control_plane_defaults.operating_system.type
  }

  lifecycle {
    ignore_changes = [disk[0].file_id]
  }

}
