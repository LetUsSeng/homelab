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

## ArgoCD is not self-managed
ArgoCD itself is installed by `scripts/install-argocd.sh`, not by an Application, so a broken
ArgoCD can always be fixed by re-running the script. Chart or values changes need a re-run.

## Adding an app
The `root` Application watches `gitops/argoproj/apps/`, so adding an app is one file there
plus a push to `master`. Applications sync from github, never from your working tree.

## Migration status
Managed by ArgoCD: `cert-manager-crds`, `metallb-config`, `proxmox` (plain manifests).

Still installed by `scripts/install-*.sh`: traefik, metallb, longhorn, pihole, external-dns,
cert-manager. These are live helm releases; ArgoCD templates charts itself instead of reusing
a release, so migrate them one at a time and verify each before moving on.
