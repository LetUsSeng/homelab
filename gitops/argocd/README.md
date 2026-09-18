# ArgoCD

Syncs this repo (`https://github.com/LetUsSeng/homelab`, branch `master`) into the cluster.
UI: https://cd.letusseng.com (traefik terminates tls with the wildcard cert, so argocd-server
runs with `server.insecure=true`).

## Install
- run `./scripts/install-traefik.sh` first
- `./scripts/install-argocd.sh` installs the chart and applies `gitops/argoproj/root-app.yaml`

Initial admin password:
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## ArgoCD is self-managed
ArgoCD manages itself through `gitops/argoproj/apps/argocd.yaml`, so chart and values changes are
a commit to `master`. The chart version lives only in that Application; `scripts/install-argocd.sh`
reads `targetRevision` out of it, so the two can't drift.

`scripts/install-argocd.sh` is the bootstrap and the break-glass path. The helm release is kept on
purpose, so re-running the script is a normal `helm upgrade`. To fix a broken argocd by hand:
```
argocd app set argocd --sync-policy none   # stop selfHeal reverting you
./scripts/install-argocd.sh
argocd app set argocd --sync-policy automated
```
The chart's `argocd-redis-secret-init` helm hook becomes a PreSync hook, so that Job runs on every
sync of this app. It is idempotent (it only creates the `argocd-redis` secret when missing).

## Adding an app
The `root` Application watches `gitops/argoproj/apps/`, so adding an app is one file there
plus a push to `master`. Applications sync from github, never from your working tree.

## Migration status
Managed by ArgoCD: `argocd` itself, plus `cert-manager-crds`, `metallb-config`, `proxmox`
(plain manifests).

Still installed by `scripts/install-*.sh`: traefik, metallb, longhorn, pihole, external-dns,
cert-manager. These are live helm releases; ArgoCD templates charts itself instead of reusing
a release, so migrate them one at a time and verify each before moving on.
