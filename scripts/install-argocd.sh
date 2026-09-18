#!/usr/bin/env bash
set -euo pipefail

ARGOCD_CHART_VERSION=10.9.2
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# NOTE:
# The UI is served through traefik (cd.letusseng.com), so run install-traefik.sh first.
kubectl get namespace traefik >/dev/null

# NOTE:
# argocd runs as non-root with all capabilities dropped, so the namespace can stay
# on Talos' default pod security standard.
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo-cd \
	--repo https://argoproj.github.io/argo-helm \
	--version "$ARGOCD_CHART_VERSION" \
	--namespace argocd \
	--values "$ROOT_DIR/gitops/argocd/values.yaml" \
	--wait

kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd rollout status deploy/argocd-repo-server
kubectl -n argocd rollout status deploy/argocd-applicationset-controller
kubectl -n argocd rollout status statefulset/argocd-application-controller

# NOTE:
# The app-of-apps points at github.com/LetUsSeng/homelab, which is public, so argocd
# needs no repo credentials. Applications only sync what is pushed to master.
# The Application CRD arrives with the chart above, so retry while the api catches up.
for _ in {1..10}; do
	if kubectl apply -f "$ROOT_DIR/gitops/argoproj/root-app.yaml"; then
		echo "admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
		exit 0
	fi
	sleep 5
done

echo "failed to apply gitops/argoproj/root-app.yaml" >&2
exit 1
