#!/usr/bin/env bash
set -euo pipefail

# Secrets the monitoring charts expect to already exist. Argocd syncs the charts from git,
# so the credentials have to come from somewhere outside it: run this once before the apps sync.

# NOTE:
# node-exporter needs hostPath/hostPID, which talos' default baseline pod security standard
# blocks. Argocd also sets these labels (managedNamespaceMetadata), this is for the case where
# the bootstrap runs before the first sync.
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring --overwrite \
	pod-security.kubernetes.io/enforce=privileged \
	pod-security.kubernetes.io/audit=privileged \
	pod-security.kubernetes.io/warn=privileged

# NOTE:
# Generate only when the secret is missing, so re-runs never rotate credentials (the grafana
# chart's default adminPassword is literally "strongpassword"). Process substitution keeps the
# values out of argv and logs.
rand() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }

if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
	kubectl -n monitoring create secret generic grafana-admin \
		--from-literal=admin-user=admin \
		--from-file=admin-password=<(rand)
fi

# NOTE:
# admin-token is what proxmox uses for its influxdb metric server, see gitops/monitoring/README.md.
if ! kubectl -n monitoring get secret influxdb-auth >/dev/null 2>&1; then
	kubectl -n monitoring create secret generic influxdb-auth \
		--from-file=admin-password=<(rand) \
		--from-file=admin-token=<(rand)
fi

echo "grafana admin password: kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d"
echo "influxdb admin token:   kubectl -n monitoring get secret influxdb-auth -o jsonpath='{.data.admin-token}' | base64 -d"
