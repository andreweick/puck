#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
restore-drill.sh --node <TEST_CP_IP> --snapshot <PATH> [--skip-hash-check]

Restores a Talos control-plane (TEST VM) from a given etcd snapshot.
Only run this against a **throwaway** control-plane VM in PREPARING state.

Example:
  ./restore-drill.sh --node 10.10.10.50 --snapshot ./db-2025-10-10.snapshot
EOF
  exit 1
}

NODE=""; SNAP=""; SKIP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --node) NODE="$2"; shift 2;;
    --snapshot) SNAP="$2"; shift 2;;
    --skip-hash-check) SKIP="--recover-skip-hash-check"; shift;;
    *) usage;;
  esac
done

[[ -n "$NODE" && -n "$SNAP" ]] || usage

echo "Checking etcd state on $NODE ..."
talosctl -n "$NODE" service etcd || true
echo "Proceeding to restore from $SNAP in 5 seconds... (Ctrl+C to abort)"
sleep 5

talosctl -n "$NODE" bootstrap --recover-from "$SNAP" ${SKIP}

echo "Waiting 10s, then checking status..."
sleep 10
talosctl -n "$NODE" etcd status || true

echo "Attempting to fetch kubeconfig:"
talosctl -n "$NODE" kubeconfig . --force || true

echo "Restore drill done. Inspect kubeconfig and kubectl connectivity if desired."
