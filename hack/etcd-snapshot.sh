#!/usr/bin/env bash
set -euo pipefail
NODE="${1:-}"; OUT="${2:-./etcd-snapshot.db}"
[[ -n "$NODE" ]] || { echo "need control plane node IP"; exit 1; }
talosctl --nodes "$NODE" etcd snapshot "$OUT"
echo "Snapshot saved to $OUT"
