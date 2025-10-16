# puck: Talos on Proxmox — Ordered Setup (v10.1)

Sequence: **control plane + worker** → **Caddy (static Caddyfile)** → **Caddy ingress** → **Postgres (local NVMe)** → **Immich (NFS)**.

- Helm charts pinned. Use **Renovate** PRs to review upgrades.
- Backups: run `hack/backup/` from a Pi/VM (off-cluster) → rsync.net (**with Healthchecks**).
- Restore drill: `hack/drills/` (try it quarterly).
- Optional remote admin path: `docs/tailscale-mgmt.md`.

**Talos Image**: use one ISO (control-plane & worker) from Image Factory with **only `qemu-guest-agent`** extension for Proxmox. Add iSCSI/util-linux later if you adopt Longhorn.
