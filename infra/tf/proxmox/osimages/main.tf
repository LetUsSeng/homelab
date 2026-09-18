resource "proxmox_download_file" "ubuntu_24_noble_qcow2_img" {
  count = length(local.pve_nodes)

  node_name    = local.pve_nodes[count.index]
  content_type = "iso"
  datastore_id = "local"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  overwrite = false
  verify = false
}

resource "proxmox_download_file" "talos" {
  count = length(local.pve_nodes)

  content_type = "iso"
  # NOTE: Maybe make this configurable
  datastore_id = "local"
  node_name    = local.pve_nodes[count.index]
  url          = "https://github.com/siderolabs/talos/releases/download/v1.14.0/metal-amd64.iso"
  overwrite    = true
  verify = false
}
