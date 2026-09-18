#!/usr/bin/env bash
set -euo pipefail

PIHOLE_CHART_VERSION=2.38.0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
