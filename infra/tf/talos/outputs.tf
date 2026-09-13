output "control_plane_ipv4_info" {
  value = {
    for key, vm in proxmox_virtual_environment_vm.control_plane :
    key => one([for ip in flatten(vm.ipv4_addresses) : ip if startswith(ip, "10.0.0.")])
  }
}
