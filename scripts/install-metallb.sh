#!/usr/bin/env bash
set -euo pipefail

METALLB_CHART_VERSION=0.16.1
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# NOTE:
# Talos enforces the baseline pod security standard and the speaker
# needs host networking, so the namespace has to be privileged.
kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace metallb-system --overwrite \
	pod-security.kubernetes.io/enforce=privileged \
	pod-security.kubernetes.io/audit=privileged \
	pod-security.kubernetes.io/warn=privileged

helm upgrade --install metallb metallb \
	--repo https://metallb.github.io/metallb \
	--version "$METALLB_CHART_VERSION" \
	--namespace metallb-system \
	--values "$ROOT_DIR/gitops/metallb/values.yaml" \
	--wait

kubectl -n metallb-system rollout status deploy/metallb-controller
kubectl -n metallb-system rollout status ds/metallb-speaker

# NOTE:
# The validating webhook can lag behind the rollout, so retry the pool/advertisement.
for _ in {1..10}; do
	if kubectl apply -k "$ROOT_DIR/gitops/metallb-config"; then
		exit 0
	fi
	sleep 5
done

echo "failed to apply gitops/metallb-config" >&2
exit 1
