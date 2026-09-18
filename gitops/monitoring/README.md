# Monitoring

Metrics, logs and proxmox telemetry. Everything runs in the `monitoring` namespace and is synced by
argocd (`gitops/argoproj/apps/{prometheus,loki,alloy,grafana,influxdb}.yaml`).

| app | chart | what it does |
| --- | --- | --- |
| prometheus | prometheus 29.30.1 | metrics, with node-exporter + kube-state-metrics |
| loki | loki 7.3.0 | logs, SingleBinary on a longhorn pvc |
| alloy | alloy 1.12.1 | daemonset shipping pod logs into loki |
| grafana | grafana 13.2.5 | ui at https://grafana.letusseng.com |
| influxdb | influxdb2 2.1.2 | proxmox metrics, https://influxdb.letusseng.com |

Prometheus and loki are cluster-internal; reach them through grafana, or `kubectl port-forward`.

## Install
Run the bootstrap **before** the apps sync, so the charts find their credentials:
```
./scripts/bootstrap-monitoring-secrets.sh
```
It creates the `monitoring` namespace and the `grafana-admin` / `influxdb-auth` secrets, and only
generates what is missing, so re-runs never rotate anything.

```
# grafana login: admin
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
kubectl -n monitoring get secret influxdb-auth -o jsonpath='{.data.admin-token}' | base64 -d
```

## Why the namespace is privileged
node-exporter needs hostPath and hostPID, which talos' default baseline pod security standard
blocks, so the namespace is labeled privileged (same as `metallb-system`). Argocd keeps the labels
in place through `managedNamespaceMetadata` on each app.

## Proxmox metrics
PVE pushes its own host and VM metrics; nothing scrapes it. Add the metric server once per cluster
in **Datacenter > Metric Server > Add > InfluxDB**:

| field | value |
| --- | --- |
| Name | `homelab` |
| Server | `influxdb.letusseng.com` |
| Port | `443` |
| Protocol | `HTTPS` |
| Organization | `homelab` |
| Bucket | `proxmox` |
| Token | see below |

The `admin-token` from `influxdb-auth` works, but it can do anything in influx. Better: in the
influx ui (https://influxdb.letusseng.com) go to **Load Data > API Tokens > Generate > Custom API
Token**, give it write access to the `proxmox` bucket only, and use that.

Data lands in grafana's InfluxDB datasource (Flux, org `homelab`, bucket `proxmox`).

## Retention
prometheus 30d / 20Gi, loki 14d / 20Gi, influxdb 10Gi, grafana 5Gi. Loki only deletes because the
compactor runs with `retention_enabled` — `retention_period` alone does nothing. All volumes are on
longhorn, which allows expansion if they fill up.

## Notes
- The prometheus chart's default scrape config finds the apiserver, nodes, cadvisor, and any pod or
  service annotated `prometheus.io/scrape: "true"`. Annotating traefik, longhorn and cert-manager is
  a good follow-up.
- alertmanager and pushgateway are disabled; enable alertmanager once there's a receiver to send to.
- The loki chart defaults to SimpleScalable with memcached caches (chunks-cache alone asks for 8GB),
  so `gitops/loki/values.yaml` turns all of that off. Don't drop those overrides.
