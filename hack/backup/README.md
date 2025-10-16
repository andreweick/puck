# Off-cluster backup runner (Pi/VM)

Back up **etcd** snapshots to **rsync.net** on a schedule, **outside** the cluster.

## Quick start (rsync.net)
1) Install `talosctl` (see `install-talosctl.sh`).  
2) Copy scripts and create `/etc/puck/backup.env` from `backup.env.example`.  
3) Install service & timer:
```bash
sudo install -m0755 puck-etcd-rsync.sh /usr/local/bin/puck-etcd-rsync.sh
sudo cp puck-etcd-backup.service /etc/systemd/system/
sudo cp puck-etcd-backup.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now puck-etcd-backup.timer
sudo systemctl start puck-etcd-backup.service
```
4) Optional `HC_URL` to ping Healthchecks on start/success/fail.

## Alternatives
- `puck-etcd-restic.sh` (encrypted repo + retention)
- `puck-etcd-rclone.sh` (SFTP remote)

> Talos API is gRPC+mTLS; use **talosctl** (the scripts auto-detect a local copy or PATH).
