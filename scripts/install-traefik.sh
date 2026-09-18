#!/usr/bin/env bash
set -euo pipefail

TRAEFIK_CHART_VERSION=41.5.0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# NOTE:
# Unlike longhorn and metallb, traefik runs as non-root with all capabilities
# dropped, so the namespace can stay on Talos' default pod security standard.
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -

# NOTE:
# Helm only installs the chart's CRDs (IngressRoute, Middleware, ServersTransport, ...)
# on the first install. When bumping the chart version, apply the new CRDs first:
#   helm show crds traefik --repo https://traefik.github.io/charts --version <new> | kubectl apply --server-side -f -
helm upgrade --install traefik traefik \
	--repo https://traefik.github.io/charts \
	--version "$TRAEFIK_CHART_VERSION" \
	--namespace traefik \
	--values "$ROOT_DIR/gitops/traefik/values.yaml" \
	--wait

kubectl -n traefik rollout status deploy/traefik
