# PiHole

LAN DNS on `10.0.0.101`, serving the local `letusseng.com` zone (every subdomain points at traefik on
`10.0.0.103`, infra hosts are listed in `values.yaml`). Web UI: https://pihole.letusseng.com/admin

## Install
Argo syncs the chart and `manifests/` (`gitops/argoproj/apps/pihole.yaml`, which owns the chart
version). `./scripts/install-pihole.sh` is only for bootstrapping a fresh cluster and as the
break-glass path when argocd is broken: it creates the `pihole` namespace, a random `pihole-admin`
secret if missing, and runs the same chart version with helm.

The nodes resolve through comcast, not pihole, so argocd can still sync a fix when pihole is down.

Read the admin password: `kubectl -n pihole get secret pihole-admin -o jsonpath='{.data.password}' | base64 -d`

## Admin password
Once infisical is up, `manifests/infisical-secret.yaml` keeps `pihole-admin` in sync from infisical
`homelab` / `prod` / `/pihole/admin` (key `password`), and external-dns reads the same folder, see
`gitops/infisical/README.md`. Change it there: pihole and external-dns restart on their own
(auto-reload), which is a short LAN dns outage since pihole runs one replica, and external-dns
crash-loops until pihole is back.
