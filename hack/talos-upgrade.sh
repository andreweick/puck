#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  plan) echo "This drains nodes then upgrades Talos OS or Kubernetes.";;
  os)
    TALOS_VERSION="${1:-}"; NODES="${2:-}"
    [[ -n "$TALOS_VERSION" && -n "$NODES" ]] || { echo "Usage: $0 os <talosVersion> <node1,node2>"; exit 1; }
    for n in ${NODES//,/ }; do
      echo ">>> Upgrading Talos on $n to $TALOS_VERSION"
      kubectl drain "$n" --ignore-daemonsets --delete-emptydir-data || true
      talosctl --nodes "$n" upgrade --image "factory.talos.dev/installer/$TALOS_VERSION"
      kubectl uncordon "$n" || true
    done
    ;;
  kubernetes)
    K8S_VERSION="${1:-}"
    [[ -n "$K8S_VERSION" ]] || { echo "Usage: $0 kubernetes <vX.Y.Z>"; exit 1; }
    talosctl upgrade-k8s --to "$K8S_VERSION"
    ;;
  *) echo "Usage: $0 plan | os <talosVersion> <node1,node2> | kubernetes <vX.Y.Z>"; exit 1;;
esac
