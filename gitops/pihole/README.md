# PiHole

LAN DNS on `10.0.0.101`, serving the local `letusseng.com` zone (every subdomain points at traefik on
`10.0.0.103`, infra hosts are listed in `values.yaml`). Web UI: https://pihole.letusseng.com/admin

## Install
- `./scripts/install-pihole.sh` creates the `pihole` namespace and a random `pihole-admin` secret if missing
- read the admin password: `kubectl -n pihole get secret pihole-admin -o jsonpath='{.data.password}' | base64 -d`
