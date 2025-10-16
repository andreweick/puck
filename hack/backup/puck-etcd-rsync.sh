#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="/etc/puck/backup.env"; [[ -f "$ENV_FILE" ]] && . "$ENV_FILE"
: "${CP_NODE:?set CP_NODE}"; : "${RSYNC_DEST:?set RSYNC_DEST}"
SSH_OPTS="${SSH_OPTS:-}"; TMPDIR="${TMPDIR:-/tmp}"; HC_URL="${HC_URL:-}"

start_ping() { [[ -n "$HC_URL" ]] && curl -fsS -m 10 --retry 2 "$HC_URL/start" >/dev/null || true; }
fail_ping()  { [[ -n "$HC_URL" ]] && curl -fsS -m 10 --retry 2 "$HC_URL/fail"  >/dev/null || true; }
ok_ping()    { [[ -n "$HC_URL" ]] && curl -fsS -m 10 --retry 2 "$HC_URL"       >/dev/null || true; }

trap 'fail_ping' ERR
start_ping

# locate talosctl
if command -v talosctl >/dev/null 2>&1; then TALOSCTL="$(command -v talosctl)";
elif [[ -x "$(dirname "$0")/talosctl" ]]; then TALOSCTL="$(dirname "$0")/talosctl";
else echo "talosctl not found"; exit 1; fi

TS="$(date +%F_%H%M%S)"
TMP="$(mktemp -d ${TMPDIR%/}/puck-etcd.XXXXXX)"
SNAP="$TMP/etcd-$TS.snapshot"

echo "Creating etcd snapshot from $CP_NODE..."
"$TALOSCTL" -n "$CP_NODE" etcd snapshot "$SNAP"

echo "Uploading to $RSYNC_DEST ..."
rsync -av -e "ssh $SSH_OPTS" "$SNAP" "$RSYNC_DEST/"

# retention (30 days)
ssh $SSH_OPTS "$(echo "$RSYNC_DEST" | cut -d: -f1)" "find $(echo "$RSYNC_DEST" | cut -d: -f2) -name 'etcd-*.snapshot' -mtime +30 -delete" || true

rm -f "$SNAP"; rmdir "$TMP" || true
ok_ping
echo "Done."
