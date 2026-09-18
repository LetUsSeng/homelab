#!/usr/bin/env bash
set -euo pipefail

EXTERNAL_DNS_CHART_VERSION=1.22.0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# NOTE:
# external-dns runs as non-root with all capabilities dropped, so the namespace
# can stay on Talos' default pod security standard.
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -

# NOTE:
# Secrets are namespaced, so copy the pihole admin password (created by
# install-pihole.sh) into this namespace. Process substitution keeps it out of
# argv and logs. A changed password needs `kubectl -n external-dns rollout restart deploy/external-dns`.
kubectl -n external-dns create secret generic pihole-password \
	--from-file=EXTERNAL_DNS_PIHOLE_PASSWORD=<(kubectl -n pihole get secret pihole-admin -o jsonpath='{.data.password}' | base64 -d) \
	--dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install external-dns external-dns \
	--repo https://kubernetes-sigs.github.io/external-dns \
	--version "$EXTERNAL_DNS_CHART_VERSION" \
	--namespace external-dns \
	--values "$ROOT_DIR/gitops/external-dns/values.yaml" \
	--wait

kubectl -n external-dns rollout status deploy/external-dns
