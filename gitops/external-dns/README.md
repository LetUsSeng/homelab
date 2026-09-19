# External DNS

Publishes `letusseng.com` records into pihole:
- every Ingress host under `letusseng.com`
- Services annotated with `external-dns.kubernetes.io/hostname: <name>.letusseng.com`
  (external-dns v0.22+ no longer reads the old `external-dns.alpha.kubernetes.io/` prefix)

Records override pihole's `*.letusseng.com -> traefik` wildcard for that name.

## Install
Argo syncs the chart and `manifests/` (`gitops/argoproj/apps/external-dns.yaml`, which owns the chart
version). `./scripts/install-external-dns.sh` is only for bootstrapping a fresh cluster and as the
break-glass path when argocd is broken: run `./scripts/install-pihole.sh` first, then it copies the
pihole admin password into `external-dns/pihole-password` and runs the same chart version with helm.

Once infisical is up, `manifests/infisical-secret.yaml` keeps `pihole-password` in sync from
`/pihole/admin`, and external-dns restarts when it changes.

## Caveat
The policy is `upsert-only`, so deleting an Ingress/Service leaves its record in pihole.
Remove stale records in the pihole UI (Settings > Local DNS Records).
