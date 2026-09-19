#!/usr/bin/env bash
set -euo pipefail

# Infisical's own secrets. They cannot live in infisical (it needs them to start), so like
# bootstrap-monitoring-secrets.sh this runs once before argocd syncs gitops/infisical.
#
# Usage: INFISICAL_ADMIN_EMAIL=you@example.com ./scripts/bootstrap/bootstrap-infisical-secrets.sh
#   (defaults to your git email)

NS=infisical
SITE_URL=https://infisical.letusseng.com
ADMIN_EMAIL="${INFISICAL_ADMIN_EMAIL:-$(git config user.email)}"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# NOTE:
# Generate only when the secret is missing, so re-runs never rotate anything. Rotating
# ENCRYPTION_KEY in particular makes every secret already stored unreadable. Process substitution
# keeps the values out of argv and logs.
rand() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }
exists() { kubectl -n "$NS" get secret "$1" >/dev/null 2>&1; }
get() { kubectl -n "$NS" get secret "$1" -o jsonpath="{.data.$2}" | base64 -d; }

# owner of the infisical database, see gitops/infisical/manifests/postgres-cluster.yaml
if ! exists infisical-db-credentials; then
	kubectl -n "$NS" create secret generic infisical-db-credentials \
		--type=kubernetes.io/basic-auth \
		--from-literal=username=infisical \
		--from-file=password=<(rand)
fi

# see gitops/infisical/manifests/valkey.yaml
if ! exists infisical-redis; then
	kubectl -n "$NS" create secret generic infisical-redis \
		--from-file=password=<(rand)
fi

# the server's env (infisical.kubeSecretRef). Connection strings are built from the two secrets
# above, so they always agree with what postgres and valkey were started with.
if ! exists infisical-secrets; then
	kubectl -n "$NS" create secret generic infisical-secrets \
		--from-file=ENCRYPTION_KEY=<(openssl rand -hex 16) \
		--from-file=AUTH_SECRET=<(openssl rand -base64 32) \
		--from-file=DB_CONNECTION_URI=<(printf 'postgresql://infisical:%s@infisical-db-rw.%s.svc:5432/infisical' "$(get infisical-db-credentials password)" "$NS") \
		--from-file=REDIS_URL=<(printf 'redis://:%s@infisical-redis.%s.svc:6379' "$(get infisical-redis password)" "$NS") \
		--from-literal=SITE_URL="$SITE_URL"
fi

# the admin login the chart's autoBootstrap job creates (gitops/infisical/values.yaml)
if ! exists infisical-bootstrap-credentials; then
	[[ -n "$ADMIN_EMAIL" ]] || { echo "set INFISICAL_ADMIN_EMAIL" >&2; exit 1; }
	kubectl -n "$NS" create secret generic infisical-bootstrap-credentials \
		--from-literal=INFISICAL_ADMIN_EMAIL="$ADMIN_EMAIL" \
		--from-file=INFISICAL_ADMIN_PASSWORD=<(rand)
fi

cat <<EOF

!!! Save these in your password manager now. Without ENCRYPTION_KEY and AUTH_SECRET a restored
!!! database is unreadable, and nothing backs them up.
  kubectl -n $NS get secret infisical-secrets -o jsonpath='{.data.ENCRYPTION_KEY}' | base64 -d
  kubectl -n $NS get secret infisical-secrets -o jsonpath='{.data.AUTH_SECRET}' | base64 -d

admin login ($SITE_URL):
  kubectl -n $NS get secret infisical-bootstrap-credentials -o jsonpath='{.data.INFISICAL_ADMIN_EMAIL}' | base64 -d
  kubectl -n $NS get secret infisical-bootstrap-credentials -o jsonpath='{.data.INFISICAL_ADMIN_PASSWORD}' | base64 -d
EOF
