# Talos Worker with Two Disks

## Proxmox VM Setup

Create the worker VM with two virtual disks:

```bash
qm create 101 --name talos-worker-01 --cores 9 --memory 43008 --net0 virtio,bridge=vmbr0
qm set 101 --scsihw virtio-scsi-single \
  --scsi0 local:50,discard=on,ssd=1 \       # OS disk (Drive 1)
  --scsi1 local2:700,discard=on,ssd=1       # Data disk (Drive 2)
```

Adjust `local` and `local2` to match your Proxmox storage names (check in Proxmox UI under Datacenter → Storage).

## Talos Machine Config

Add this to your **worker machine config** (the YAML you generate with `talosctl gen config`):

```yaml
machine:
  disks:
    - device: /dev/sdb  # Second disk (700GB)
      partitions:
        - mountpoint: /var/mnt/data
```

## Verification

After applying the config, verify the disk is mounted:

```bash
talosctl -n <WORKER_IP> ls /var/mnt/data
talosctl -n <WORKER_IP> df -h | grep sdb
```

## Storage Classes

- **local-path** (700GB data disk): For PostgreSQL, persistent app data
- **nfs-csi** (Synology NAS): For Immich photos, backups, shared data

PostgreSQL uses `local-path` (see `apps/work/postgres/cluster.yaml:11`):
```yaml
storage:
  size: 100Gi
  storageClass: local-path  # Now on /var/mnt/data (700GB disk)
```

## Growing the Data Disk Later

If you need more space:

1. In Proxmox: Resize the scsi1 disk (e.g., 700GB → 900GB)
2. In Talos: The partition will auto-resize on next boot

```bash
# Check before
talosctl -n <WORKER_IP> df -h

# Resize in Proxmox UI or CLI
qm resize 101 scsi1 +200G

# Reboot worker
talosctl -n <WORKER_IP> reboot

# Check after
talosctl -n <WORKER_IP> df -h
```
