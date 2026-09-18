#!/usr/bin/env bash
set -euo pipefail

CERT_MANAGER_CHART_VERSION=v1.21.2
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# NOTE:
# The wildcard Certificate is created in the traefik namespace (traefik serves it as
# its default cert), so run install-traefik.sh first.
kubectl get namespace traefik >/dev/null

# NOTE:
# cert-manager runs as non-root with all capabilities dropped, so the namespace
# can stay on Talos' default pod security standard.
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# NOTE:
# The Cloudflare API token (Zone:DNS:Edit + Zone:Zone:Read on letusseng.com) lives in
# the repo's .env. Process substitution keeps it out of argv and logs.
set -a
# shellcheck disable=SC1091
. "$ROOT_DIR/.env"
set +a
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN must be set in .env}"
kubectl -n cert-manager create secret generic cloudflare-api-token \
	--from-file=api-token=<(printf %s "$CLOUDFLARE_API_TOKEN") \
	--dry-run=client -o yaml | kubectl apply -f -

# NOTE:
# CRDs are installed and upgraded by the chart (crds.enabled in values.yaml).
helm upgrade --install cert-manager cert-manager \
	--repo https://charts.jetstack.io \
	--version "$CERT_MANAGER_CHART_VERSION" \
	--namespace cert-manager \
	--values "$ROOT_DIR/gitops/cert-manager/values.yaml" \
	--wait

kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-webhook
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector

# NOTE:
# The validating webhook can lag behind the rollout, so retry the issuer/certificate.
for _ in {1..10}; do
	if kubectl apply -k "$ROOT_DIR/gitops/cert-manager-crds"; then
		exit 0
	fi
	sleep 5
done

echo "failed to apply gitops/cert-manager-crds" >&2
exit 1
