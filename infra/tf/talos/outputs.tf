output "control_plane_ipv4_info" {
  value = { for key, vm in proxmox_virtual_environment_vm.control_plane : key => flatten(vm.ipv4_addresses) }
}
