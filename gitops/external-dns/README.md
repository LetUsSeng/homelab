# External DNS

Publishes `letusseng.com` records into pihole:
- every Ingress host under `letusseng.com`
- Services annotated with `external-dns.kubernetes.io/hostname: <name>.letusseng.com`
  (external-dns v0.22+ no longer reads the old `external-dns.alpha.kubernetes.io/` prefix)

Records override pihole's `*.letusseng.com -> traefik` wildcard for that name.

## Install
- run `./scripts/install-pihole.sh` first
- `./scripts/install-external-dns.sh` copies the pihole admin password into `external-dns/pihole-password`
- once infisical is up, `gitops/pihole/manifests/infisical-secret.yaml` keeps that copy in sync, and
  external-dns restarts when it changes

## Caveat
The policy is `upsert-only`, so deleting an Ingress/Service leaves its record in pihole.
Remove stale records in the pihole UI (Settings > Local DNS Records).
