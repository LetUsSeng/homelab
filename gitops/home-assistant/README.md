# Home Assistant

https://ha.letusseng.com, installed from plain manifests since there's no official chart. The
container install, so no supervisor or add-ons: anything that would be an add-on runs as its own app.

| piece | where | notes |
| --- | --- | --- |
| home assistant | `statefulset.yaml` | `hostNetwork` for lan discovery, `/config` on a 5Gi longhorn pvc |
| config | `configuration.yaml` | mounted read-only, edits roll the pod (kustomize name hash) |
| http / reverse proxy | `http.json` | copied to `/config/.storage/http` by the init container on every start |
| recorder db | `postgres-cluster.yaml` | cnpg `home-assistant-db`, 2 instances; creds in the generated `home-assistant-db-app` |
| long-term history | `infra/tf/home-assistant` | influxdb bucket `home-assistant` + write-only token |

## Why hostNetwork
mDNS, SSDP and broadcast discovery (chromecasts, printers, most lan integrations) only see the
pod network otherwise. Talos' baseline pod security rejects it, so the namespace is labelled
privileged (`namespace.yaml`). `dnsPolicy: ClusterFirstWithHostNet` keeps cluster dns working, and
`trusted_proxies` covers both the pod cidr and the node subnet, because traefik's requests can come
from either.

## Why http.json and not yaml
Since 2026.9, home assistant keeps its http settings in `.storage/http` as a `stable`/`pending` pair.
A yaml `http:` block is imported only once, as `pending`, and it reverts to `stable` unless an
admin confirms it (websocket `http/config/promote`) within 5 minutes. A fresh install behind
traefik can't do that: onboarding needs the proxy settings before any admin exists. After that
first import the yaml is ignored for good (`yaml_migration_done`).

So `http.json` holds the whole store file with the proxy settings already in `stable`, and the init
container overwrites `.storage/http` with it on every start. `stable` is used as-is, with no revert
timer. Git is the source of truth: http changes made in the ui are reset on the next restart. Put
them in `http.json` instead. The fields match `HTTP_STORAGE_SCHEMA` in
`homeassistant/components/http/config.py`; check it for storage version bumps when upgrading.

## Install
1. Merge to master. Argo syncs the app: namespace, then the cnpg cluster (wave -1), then home
   assistant.
2. Create the influxdb bucket and token (the namespace has to exist first):
   ```
   aws sso login --profile homelab
   tofu -chdir=infra/tf/home-assistant init
   tofu -chdir=infra/tf/home-assistant apply
   ```
3. Open https://ha.letusseng.com and finish onboarding.
4. Settings > Devices & services > Add integration > InfluxDB, api v2:
   - url `http://influxdb-influxdb2.monitoring.svc.cluster.local`, organization `homelab`,
     bucket `home-assistant`
   - token: `kubectl -n home-assistant get secret influxdb-token -o jsonpath='{.data.token}' | base64 -d`

   The integration is ui-configured now; putting the connection in `configuration.yaml` only
   imports it once and then raises a deprecation repair. Include/exclude filters can still go in
   yaml under `influxdb:`.

Grafana already has the influxdb datasource; its default bucket is `proxmox`, so name
`home-assistant` in queries.

## Backups
The longhorn pvc (3 replicas) survives a lost node, and the recorder has a cnpg replica. For config
mistakes, use home assistant's own backups (Settings > System > Backups), written to
`/config/backups` on the pvc. Copy them off the cluster if they need to survive losing it. The
influxdb history has no backup, the same as proxmox's metrics.

## Upgrading
Bump the image tag in `statefulset.yaml` (both the container and the init container) and read the
release notes' breaking changes first. If the `http` storage version changed, update `http.json`
to match.
