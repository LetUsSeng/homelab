# PiHole

LAN DNS on `10.0.0.101`, serving the local `letusseng.com` zone (every subdomain points at traefik on
`10.0.0.103`, infra hosts are listed in `values.yaml`). Web UI: https://pihole.letusseng.com/admin

## Install
- `./scripts/install-pihole.sh` creates the `pihole` namespace and a random `pihole-admin` secret if missing
- read the admin password: `kubectl -n pihole get secret pihole-admin -o jsonpath='{.data.password}' | base64 -d`

## Admin password
Once infisical is up, the `pihole-secrets` argo app (`manifests/`) keeps `pihole-admin` and its
external-dns copy in sync from infisical `homelab` / `prod` / `/pihole/admin` (key `password`), see
`gitops/infisical/README.md`. Change it there: pihole and external-dns restart on their own
(auto-reload), which is a short LAN dns outage since pihole runs one replica.
