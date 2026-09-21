# Home Assistant

https://ha.letusseng.com, installed from plain manifests since there's no official chart. The
container install, so no supervisor or add-ons: anything that would be an add-on runs as its own app.

| piece | where | notes |
| --- | --- | --- |
| home assistant | `statefulset.yaml` | `hostNetwork` for lan discovery, `/config` on a 5Gi longhorn pvc |
| config | `configuration.yaml` | mounted read-only, edits roll the pod (kustomize name hash) |
| recorder db | `postgres-cluster.yaml` | cnpg `home-assistant-db`, 2 instances; creds in the generated `home-assistant-db-app` |
| long-term history | `infra/tf/home-assistant` | influxdb bucket `home-assistant` + write-only token |

## Why hostNetwork
mDNS, SSDP and broadcast discovery (chromecasts, printers, most lan integrations) only see the
pod network otherwise. Talos' baseline pod security rejects it, so the namespace is labelled
privileged (`namespace.yaml`). `dnsPolicy: ClusterFirstWithHostNet` keeps cluster dns working, and
`trusted_proxies` covers both the pod cidr and the node subnet, because traefik's requests can come
from either.

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
release notes' breaking changes first.
