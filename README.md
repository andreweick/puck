# puck (homelab gitops) — v10.1

Talos + Kubernetes on Proxmox with **Flux**, **Cilium**, **Caddy**, **Cloudflare Tunnel**, **Tailscale** and storage via **NFS CSI** (Synology). Includes **Flux Image Automation**, **Renovate**, **DR docs**, **off-cluster backup runner** for etcd → rsync.net, and **Tailscale management** notes.

> **What’s new in v10.1**
> - Added **docs/tailscale-mgmt.md** (how to expose only :6443 and :50000 on your tailnet).
> - Preserves v10 Healthchecks pings + restore drill.
> - Full repo layout (infra/apps) with pinned chart versions.

## Retronyms for "puck"
- **Project Unattended Cloud Kubernetes**
- **Proxmox Unified Cluster Kit**

## Repo layout (high level)
```
clusters/prod/              # Flux points here and reconciles infra/ then apps/
infra/                      # Cilium, NFS CSI, local-path, CNPG, ingress (Caddy), tailscale, image automation
apps/                       # Immich, cloudflared, Postgres (CNPG or Bitnami), MinIO, devboxes
docs/                       # ADDING-WORKLOADS, DISASTER-RECOVERY, tailscale-mgmt
hack/                       # backups (rsync/restic/rclone + HC), drills (restore), upgrades, labels, cert SANs
.github/workflows/          # Renovate + sample container build
.sops.yaml                  # encrypts secret.*.yaml with Age
```

See `recipe.md` to bootstrap in order, `docs/DISASTER-RECOVERY.md` for backups/restores, and `docs/tailscale-mgmt.md` for optional remote-only admin via Tailscale.
