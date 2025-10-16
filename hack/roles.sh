#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  roles.sh label-heavy <node>        # label x86 worker(s) as heavy
  roles.sh label-light <node>        # label Pi workers as light
  roles.sh taint-raspi <node>        # prevent general pods on Pi (opt-in)
  roles.sh untaint-raspi <node>
  roles.sh show
EOF
  exit 1
fi
cmd="$1"; shift || true
case "$cmd" in
  label-heavy)   kubectl label node "$1" workload=heavy --overwrite ;;
  label-light)   kubectl label node "$1" workload=light hardware=raspi --overwrite ;;
  taint-raspi)   kubectl taint node "$1" dedicated=raspi:NoSchedule --overwrite ;;
  untaint-raspi) kubectl taint node "$1" dedicated- || true ;;
  show)          kubectl get nodes -L workload,hardware,kubernetes.io/arch ;;
  *) echo "unknown command: $cmd"; exit 1;;
esac
