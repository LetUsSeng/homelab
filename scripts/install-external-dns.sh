#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# NOTE:
# argocd owns external-dns day-to-day (gitops/argoproj/apps/external-dns.yaml). This script is the bootstrap path
# for a fresh cluster and the break-glass path when argocd is broken, so it follows the chart version
# in the Application, the same way install-argocd.sh does.
APP_FILE="$ROOT_DIR/gitops/argoproj/apps/external-dns.yaml"
EXTERNAL_DNS_CHART_VERSION="$(sed -n 's/^ *targetRevision: *"\([0-9][^"]*\)".*/\1/p' "$APP_FILE" | head -1)"
: "${EXTERNAL_DNS_CHART_VERSION:?could not read targetRevision from $APP_FILE}"

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
