# Restore Drill (Practice etcd Recovery)

> **Goal:** Restore your cluster’s etcd from a snapshot on a **throwaway** control-plane VM, isolated from production.

## Prereqs
- A recent etcd snapshot.
- A test control-plane VM (Talos installed) on a lab/isolated network.
- Controlplane machine config matching your cluster secrets.

## Steps
1) Boot the test CP; ensure etcd is `Preparing`:
```bash
talosctl -n <TEST_CP_IP> service etcd
```
2) Restore:
```bash
talosctl -n <TEST_CP_IP> bootstrap --recover-from /path/to/db.snapshot
# If the snapshot is a raw member file, add: --recover-skip-hash-check
```
3) Verify and fetch kubeconfig:
```bash
talosctl -n <TEST_CP_IP> etcd status
talosctl -n <TEST_CP_IP> kubeconfig . --force
KUBECONFIG=./kubeconfig kubectl get ns
```
4) Destroy the test VM when done.
