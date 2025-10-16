# Disaster Recovery & Backups

## What to back up
1. **etcd snapshots** (Talos CP)
2. **Talos machine configs** (controlplane & worker YAMLs + cluster secrets)
3. **Flux repo** (this Git)
4. **App data** (CNPG dumps, Immich library, MinIO buckets)

## etcd snapshot
Preferred (healthy CP):
```bash
talosctl -n <CP_IP_OR_DNS> etcd snapshot db-$(date +%F).snapshot
```
Last-resort:
```bash
talosctl -n <CP_IP> cp /var/lib/etcd/member/snap/db ./db-disaster-$(date +%F).snapshot
```

## Restore flow
1) Boot a CP with correct machine config; ensure `etcd` service is **Preparing**.
2) Recover:
```bash
talosctl -n <CP_IP> bootstrap --recover-from=./db.snapshot
# For a copied member file: add --recover-skip-hash-check
```
3) Verify:
```bash
talosctl -n <CP_IP> etcd status
kubectl get nodes
```

## Practice (restore drill)
Use `hack/drills/restore-drill.md` and `restore-drill.sh` on a **throwaway** CP VM (isolated network). Do this quarterly.

## App-level data
- **Postgres (CNPG)**: `apps/work/postgres/pgdump-cron.yaml` (nightly dumps to NFS). Consider Barman → S3 (MinIO/R2).
- **Immich**: library on NFS; back up the share via NAS snapshot/backup.
