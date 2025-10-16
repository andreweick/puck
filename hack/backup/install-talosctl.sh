#!/usr/bin/env bash
set -euo pipefail
VER="${1:-latest}"; OS="linux"; ARCH="$(uname -m)"
case "$ARCH" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) echo "Unsupported $ARCH"; exit 1;; esac
if [[ "$VER" == "latest" ]]:
  URL="https://github.com/siderolabs/talos/releases/latest/download/talosctl-${OS}-${ARCH}"
else:
  URL="https://github.com/siderolabs/talos/releases/download/${VER}/talosctl-${OS}-${ARCH}"
fi
curl -fsSL "$URL" -o talosctl && chmod +x talosctl && sudo mv talosctl /usr/local/bin/talosctl
echo "Installed talosctl:"; talosctl version --client || true
