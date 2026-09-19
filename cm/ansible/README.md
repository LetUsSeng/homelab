# Ansible

Configuration management for the Proxmox nodes (`pve-0`, `pve-1`, `pve-2`).

## Prerequisites
- Your SSH key is in `root`'s `authorized_keys` on each node (shared across the PVE cluster).
- The nodes use the `pve-no-subscription` APT repo. If they don't, `apt update` fails with a 401 from the enterprise repo.

## Usage
```sh
make venv   # create ansible-venv and install ansible-core
make ping   # check connectivity to every node
make check  # dry run with diff
make apply  # apply changes
```

## Adding packages
Add them to `proxmox_packages` in `group_vars/proxmox.yaml`.
