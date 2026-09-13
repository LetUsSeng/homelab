locals {
  talos_version = "1.14.0"
  k8s_version   = "1.37.0"
  cluster_name  = "letusseng-cluster"

  # shared layer 2 VIP for the kubernetes api, owned by talos (not kube-vip)
  vip = "10.0.0.100"

  # extensions: iscsi-tools, qemu-guest-agent, util-linux-tools (iscsi + util-linux required by longhorn)
  talos_image_factory_id = "88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b"
  install_image          = "factory.talos.dev/installer/${local.talos_image_factory_id}:v${local.talos_version}"

  nameservers = ["75.75.75.75", "75.75.76.76"]

  control_plane_static_ipv4s = [for control_plane in local.control_planes : control_plane.ip_config.ipv4.address]

  # only keep the declared node ip, the vm also reports the vip when it holds it
  control_plane_ipv4_info = {
    for key, vm in proxmox_virtual_environment_vm.control_plane :
    key => one([for ip in flatten(vm.ipv4_addresses) : ip if contains(local.control_plane_static_ipv4s, ip)])
  }
}

resource "proxmox_download_file" "talos_image_1_14_0" {
  for_each = local.control_planes

  content_type = "iso"
  datastore_id = "local"
  node_name    = each.value.node_name
  url          = "https://factory.talos.dev/image/${local.talos_image_factory_id}/v${local.talos_version}/nocloud-amd64.iso"
  file_name    = "talos-v${local.talos_version}-nocloud-amd64.iso"
  overwrite    = false
  verify       = false
}

# NOTE: maybe move image here
resource "talos_machine_secrets" "secrets" {
  talos_version = local.talos_version
}

data "talos_client_configuration" "client" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.secrets.client_configuration
  nodes                = [for control_plane in local.control_planes : control_plane.ip_config.ipv4.address]
  endpoints            = [for control_plane in local.control_planes : control_plane.ip_config.ipv4.address]
}


data "talos_machine_configuration" "control_plane_config" {
  for_each = local.control_planes

  cluster_name       = local.cluster_name
  cluster_endpoint   = "https://${local.vip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.secrets.machine_secrets
  kubernetes_version = "v${local.k8s_version}"
  talos_version      = "v${local.talos_version}"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = local.install_image
          disk  = "/dev/sda"
        }
        network = {
          interfaces = [
            {
              deviceSelector = {
                driver = "virtio_net"
              }
              addresses = ["${each.value.ip_config.ipv4.address}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = local.control_plane_defaults.gateway
                }
              ]
              vip = {
                ip = local.vip
              }
            }
          ]
          nameservers = local.nameservers
        }
        # NOTE: Needed for metallb
        nodeLabels = {
          "node.kubernetes.io/exclude-from-external-load-balancers" = {
            "$patch" = "delete"
          }
        }
        kubelet = {
          # NOTE: longhorn stores replica data here and needs it visible to the kubelet
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = each.value.name
    })
  ]
}

resource "proxmox_virtual_environment_file" "control_plane_config" {
  for_each = local.control_planes

  content_type = "snippets"
  datastore_id = "local"
  node_name    = each.value.node_name

  source_raw {
    data      = data.talos_machine_configuration.control_plane_config[each.key].machine_configuration
    file_name = "${each.value.name}.yaml"
  }
}

resource "talos_machine_configuration_apply" "control_machine_config_apply" {
  for_each = local.control_plane_ipv4_info

  client_configuration        = talos_machine_secrets.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane_config[each.key].machine_configuration
  node                        = each.value

}

resource "talos_machine_bootstrap" "control_plane_bootstrap" {
  client_configuration = talos_machine_secrets.secrets.client_configuration
  node                 = local.control_plane_ipv4_info["control_plane_0"]
  endpoint             = local.control_plane_ipv4_info["control_plane_0"]

  depends_on = [talos_machine_configuration_apply.control_machine_config_apply]

}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  client_configuration = talos_machine_secrets.secrets.client_configuration
  node                 = local.control_plane_ipv4_info["control_plane_0"]

  depends_on = [talos_machine_bootstrap.control_plane_bootstrap]

  lifecycle {
    replace_triggered_by = [talos_machine_bootstrap.control_plane_bootstrap]
  }
}

output "talosconfig" {
  value     = data.talos_client_configuration.client.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = resource.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}
