#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# NOTE:
# argocd owns pihole day-to-day (gitops/argoproj/apps/pihole.yaml). This script is the bootstrap path
# for a fresh cluster and the break-glass path when argocd is broken, so it follows the chart version
# in the Application, the same way install-argocd.sh does.
APP_FILE="$ROOT_DIR/gitops/argoproj/apps/pihole.yaml"
PIHOLE_CHART_VERSION="$(sed -n 's/^ *targetRevision: *"\([0-9][^"]*\)".*/\1/p' "$APP_FILE" | head -1)"
: "${PIHOLE_CHART_VERSION:?could not read targetRevision from $APP_FILE}"

# NOTE:
# Pi-hole runs as root but needs no extra capabilities (the router keeps DHCP),
# so Talos' default baseline pod security standard is enough.
kubectl create namespace pihole --dry-run=client -o yaml | kubectl apply -f -

# NOTE:
# Generate the admin password only when the secret doesn't exist yet, so re-runs
# never rotate it. Process substitution keeps the password out of argv and logs.
if ! kubectl -n pihole get secret pihole-admin >/dev/null 2>&1; then
	kubectl -n pihole create secret generic pihole-admin \
		--from-file=password=<(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)
fi

# NOTE:
# The config PVC lives on longhorn and DNS is exposed on 10.0.0.101 through metallb,
# so run install-longhorn.sh, install-metallb.sh and install-traefik.sh first.
helm upgrade --install pihole pihole \
	--repo https://mojo2600.github.io/pihole-kubernetes \
	--version "$PIHOLE_CHART_VERSION" \
	--namespace pihole \
	--values "$ROOT_DIR/gitops/pihole/values.yaml" \
	--wait --timeout 10m

kubectl -n pihole rollout status deploy/pihole

echo "admin password: kubectl -n pihole get secret pihole-admin -o jsonpath='{.data.password}' | base64 -d"
