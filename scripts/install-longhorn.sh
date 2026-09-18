#!/usr/bin/env bash
#
# Install Longhorn on the Talos cluster (letusseng-cluster) with helm.
#
# Why this is more than a `helm install`: Talos is immutable, so Longhorn's host
# requirements have to be baked into the node image and machine config first.
#
#   0. (manual, reviewed) infra/tf/talos/talos.tf
#        - talos_image_factory_id -> schematic with iscsi-tools + util-linux-tools
#        - kubelet extraMounts for /var/lib/longhorn (bind, rshared, rw)
#      then: tofu -chdir=infra/tf/talos plan && tofu -chdir=infra/tf/talos apply
#      (needs AWS_PROFILE / AWS_REGION for the s3 backend, see infra/tf/README.md)
#
#   1. preflight           - tools present, show which cluster we're about to touch
#   2. check_talos_config  - make sure step 0 was applied to every node
#   3. upgrade_talos_nodes - rolling `talosctl upgrade` to the new image, one node at a
#                            time so etcd keeps quorum (all 3 nodes are control planes)
#   4. create_namespace    - Talos enforces the "baseline" pod security standard by
#                            default; longhorn needs privileged pods
#   5. install_longhorn    - helm upgrade --install with gitops/longhorn/values.yaml
#   6. verify              - rollouts done, CSI driver registered, StorageClass exists
#
# Every step is idempotent, re-running the script is safe.
#
# Usage: ./scripts/install-longhorn.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

NODES=(10.0.0.24 10.0.0.28 10.0.0.29)
SCHEMATIC="88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b"
TALOS_VERSION="v1.14.0"
INSTALL_IMAGE="factory.talos.dev/installer/${SCHEMATIC}:${TALOS_VERSION}"

CHART_VERSION="1.12.1"
NAMESPACE="longhorn-system"
VALUES="${REPO_ROOT}/gitops/longhorn/values.yaml"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# 1. tools present, show which cluster we're about to touch
preflight() {
  log "preflight"
  for bin in kubectl talosctl helm; do
    command -v "$bin" >/dev/null || die "$bin not found in PATH"
  done
  [[ -f "$VALUES" ]] || die "values file not found: $VALUES"
  echo "kube context: $(kubectl config current-context)"
  kubectl get nodes -o wide
}

# 2. the terraform changes (new install image + kubelet mount) must be on every node
check_talos_config() {
  log "checking talos machine config"
  local node config
  for node in "${NODES[@]}"; do
    config="$(talosctl -n "$node" get machineconfig -o yaml)"
    grep -q "$SCHEMATIC" <<<"$config" \
      || die "$node: install image is not schematic $SCHEMATIC, run tofu apply in infra/tf/talos"
    grep -q "/var/lib/longhorn" <<<"$config" \
      || die "$node: kubelet extraMounts missing /var/lib/longhorn, run tofu apply in infra/tf/talos"
    echo "$node: ok"
  done
}

has_longhorn_extensions() {
  local extensions
  extensions="$(talosctl -n "$1" get extensions)"
  grep -q "iscsi-tools" <<<"$extensions" && grep -q "util-linux-tools" <<<"$extensions"
}

node_name_for_ip() {
  kubectl get nodes -o wide --no-headers | awk -v ip="$1" '$6 == ip { print $1 }'
}

wait_for_etcd() {
  local node="$1" i
  for i in $(seq 1 60); do
    if talosctl -n "$node" service etcd 2>/dev/null | grep -Eq '^HEALTH +OK'; then
      return 0
    fi
    sleep 5
  done
  die "$node: etcd not healthy after 5m"
}

# 3. rolling upgrade to the image that includes iscsi-tools + util-linux-tools
upgrade_talos_nodes() {
  log "upgrading talos nodes to $INSTALL_IMAGE"
  local node name
  for node in "${NODES[@]}"; do
    if has_longhorn_extensions "$node"; then
      echo "$node: extensions already present, skipping"
      continue
    fi
    echo "$node: upgrading (node will reboot)"
    talosctl upgrade -n "$node" --image "$INSTALL_IMAGE" --wait

    name="$(node_name_for_ip "$node")"
    kubectl wait --for=condition=Ready "node/$name" --timeout=10m
    wait_for_etcd "$node"
    has_longhorn_extensions "$node" || die "$node: extensions still missing after upgrade"
    echo "$node: upgraded"
  done
}

# 4. talos defaults to baseline pod security, longhorn runs privileged pods
create_namespace() {
  log "creating namespace $NAMESPACE"
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "$NAMESPACE" --overwrite \
    pod-security.kubernetes.io/enforce=privileged \
    pod-security.kubernetes.io/audit=privileged \
    pod-security.kubernetes.io/warn=privileged
}

# 5. install/upgrade the chart pinned to the version values.yaml was written for
install_longhorn() {
  log "installing longhorn chart $CHART_VERSION"
  helm repo add longhorn https://charts.longhorn.io --force-update
  helm repo update longhorn
  helm upgrade --install longhorn longhorn/longhorn \
    --namespace "$NAMESPACE" \
    --version "$CHART_VERSION" \
    --values "$VALUES" \
    --wait --timeout 15m
}

# 6. manager/ui up, CSI driver registered by the driver deployer, StorageClass exists
verify() {
  log "verifying"
  kubectl -n "$NAMESPACE" rollout status daemonset/longhorn-manager --timeout=10m
  kubectl -n "$NAMESPACE" rollout status deployment/longhorn-driver-deployer --timeout=10m
  kubectl -n "$NAMESPACE" rollout status deployment/longhorn-ui --timeout=10m

  local i
  for i in $(seq 1 60); do
    kubectl get csidriver driver.longhorn.io >/dev/null 2>&1 && break
    sleep 5
  done
  kubectl get csidriver driver.longhorn.io >/dev/null 2>&1 || die "CSI driver driver.longhorn.io never registered"
  kubectl -n "$NAMESPACE" rollout status daemonset/longhorn-csi-plugin --timeout=10m

  kubectl get storageclass longhorn
  kubectl -n "$NAMESPACE" get nodes.longhorn.io
  kubectl -n "$NAMESPACE" get pods -o wide

  cat <<EOF

Longhorn is installed. UI:
  kubectl -n $NAMESPACE port-forward svc/longhorn-frontend 8080:80
  open http://localhost:8080
EOF
}

main() {
  preflight
  check_talos_config
  upgrade_talos_nodes
  create_namespace
  install_longhorn
  verify
}

main "$@"
