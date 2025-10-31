# Proxmox VE Initial Setup for Puck

Initial VM creation for Talos Kubernetes cluster on Proxmox VE.

## Prerequisites

- Proxmox VE installed with 2x 1TB NVMe drives
- Storage pools configured:
  - `local-lvm` (nvme0n1)
  - `sn770` (nvme1n1)
- Talos Linux ISO uploaded to `local` storage

## VM Allocation Overview

| VM ID | Name | vCPU | RAM | Disk 1 (OS) | Disk 2 (Data) | Purpose |
|---|---|---|---|---|---|---|
| 500 | puck-cp-01 | 3 | 8GB | 50GB (local-lvm) | - | Control Plane |
| 510 | puck-worker-01 | 9 | 42GB | 50GB (local-lvm) | 700GB (sn770) | Worker Node |
| 520 | windows | 2 | 8GB | 80GB (sn770) | - | Emergency use |

## Method 1: Proxmox Web UI

### Control Plane VM (puck-cp-01)

1. **Create VM**
   - Click **Create VM** (top right)
   - **VM ID**: `500`

2. **General Tab**
   - **Name**: `puck-cp-01`
   - Click **Next**

3. **OS Tab**
   - **ISO image**: Select your Talos ISO from dropdown
   - **Guest OS Type**: Linux
   - **Version**: 6.x - 2.6 Kernel
   - Click **Next**

4. **System Tab**
   - **SCSI Controller**: `VirtIO SCSI single`
   - **QEMU Agent**: ✓ **Enable** (important for Proxmox integration)
   - Leave rest as default
   - Click **Next**

5. **Disks Tab**
   - **Bus/Device**: `scsi0`
   - **Storage**: `local-lvm`
   - **Disk size**: `50` GiB
   - **Cache**: Default (no cache)
   - **Discard**: ✓ **Enable** (required for NVMe/SSD TRIM support)
   - **SSD emulation**: ✓ **Enable** (tells guest OS this is an SSD)
   - Click **Next**

6. **CPU Tab**
   - **Cores**: `3`
   - **Type**: `host` (passes through host CPU features for better performance)
   - Click **Next**

7. **Memory Tab**
   - **Memory (MiB)**: `8192` (8GB)
   - **Minimum memory**: `8192` (disables ballooning)
   - **Ballooning Device**: ✗ **Uncheck** (Talos doesn't use memory ballooning)
   - Click **Next**

8. **Network Tab**
   - **Bridge**: `vmbr0`
   - **Model**: `VirtIO (paravirtualized)`
   - Click **Next**

9. **Confirm**
   - Review all settings
   - **Start after created**: Leave unchecked (we'll configure first)
   - Click **Finish**

---

### Worker VM (puck-worker-01)

1. **Create VM**
   - Click **Create VM**
   - **VM ID**: `510`

2. **General Tab**
   - **Name**: `puck-worker-01`
   - Click **Next**

3. **OS Tab**
   - **ISO image**: Select your Talos ISO
   - **Guest OS Type**: Linux
   - **Version**: 6.x - 2.6 Kernel
   - Click **Next**

4. **System Tab**
   - **SCSI Controller**: `VirtIO SCSI single`
   - **QEMU Agent**: ✓ **Enable**
   - Click **Next**

5. **Disks Tab - First Disk (OS)**
   - **Bus/Device**: `scsi0`
   - **Storage**: `local-lvm`
   - **Disk size**: `50` GiB
   - **Cache**: Default (no cache)
   - **Discard**: ✓ **Enable**
   - **SSD emulation**: ✓ **Enable**
   - ⚠️ **DON'T click Next yet!** Click **Add** button

6. **Disks Tab - Second Disk (Data)**
   - A second disk row will appear
   - **Bus/Device**: `scsi1`
   - **Storage**: `sn770`
   - **Disk size**: `700` GiB
   - **Cache**: Default (no cache)
   - **Discard**: ✓ **Enable**
   - **SSD emulation**: ✓ **Enable**
   - Now click **Next**

7. **CPU Tab**
   - **Cores**: `9`
   - **Type**: `host`
   - Click **Next**

8. **Memory Tab**
   - **Memory (MiB)**: `43008` (42GB)
   - **Minimum memory**: `43008`
   - **Ballooning Device**: ✗ **Uncheck**
   - Click **Next**

9. **Network Tab**
   - **Bridge**: `vmbr0`
   - **Model**: `VirtIO (paravirtualized)`
   - Click **Next**

10. **Confirm**
    - Review all settings
    - Click **Finish**

---

### Windows VM (Optional - Emergency Use)

1. **Create VM**
   - VM ID: `520`
   - Name: `windows`

2. Follow similar steps:
   - **OS**: Windows 10/11
   - **Disk**: 80GB on `sn770`
   - **CPU**: 2 cores, type `host`
   - **Memory**: 8192 MiB, no ballooning
   - **QEMU Agent**: Enable (install guest agent after Windows setup)

3. **Don't start it** - only for emergency use

---

## Method 2: Command Line (SSH to Proxmox)

### Control Plane VM (puck-cp-01)

```bash
# Create VM
qm create 500 \
  --name puck-cp-01 \
  --cores 3 \
  --cpu host \
  --memory 8192 \
  --balloon 0 \
  --net0 virtio,bridge=vmbr0 \
  --agent enabled=1 \
  --ostype l26

# Add disk
qm set 500 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:50,discard=on,ssd=1

# Attach Talos ISO (adjust path if different)
qm set 500 --ide2 local:iso/talos-amd64.iso,media=cdrom

# Optional: Set boot order
qm set 500 --boot order=scsi0

# Verify configuration
qm config 500
```

### Worker VM (puck-worker-01)

```bash
# Create VM with two disks
qm create 510 \
  --name puck-worker-01 \
  --cores 9 \
  --cpu host \
  --memory 43008 \
  --balloon 0 \
  --net0 virtio,bridge=vmbr0 \
  --agent enabled=1 \
  --ostype l26

# Add OS disk (50GB on nvme0n1)
qm set 510 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:50,discard=on,ssd=1

# Add data disk (700GB on nvme1n1)
qm set 510 --scsi1 sn770:700,discard=on,ssd=1

# Attach Talos ISO
qm set 510 --ide2 local:iso/talos-amd64.iso,media=cdrom

# Set boot order
qm set 510 --boot order=scsi0

# Verify configuration
qm config 510
```

### Windows VM (Optional)

```bash
qm create 520 \
  --name windows \
  --cores 2 \
  --cpu host \
  --memory 8192 \
  --balloon 0 \
  --net0 virtio,bridge=vmbr0 \
  --agent enabled=1 \
  --ostype win11

qm set 520 \
  --scsihw virtio-scsi-single \
  --scsi0 sn770:80,discard=on,ssd=1

# Attach Windows ISO (upload first)
# qm set 520 --ide2 local:iso/windows-11.iso,media=cdrom
```

---

## Important Configuration Notes

### Key Settings Explained

- **QEMU Guest Agent (`--agent enabled=1`)**:
  - Allows Proxmox to query VM status, shutdown gracefully, get IP addresses
  - Talos image includes this by default

- **CPU Type `host`**:
  - Passes through all host CPU features to guest
  - Better performance than default `kvm64`
  - Safe for homelab where VMs won't migrate to different hardware

- **Discard (`discard=on`)**:
  - Enables TRIM/UNMAP support for NVMe/SSD
  - Allows guest OS to tell Proxmox when blocks are freed
  - Prevents disk space waste

- **SSD Emulation (`ssd=1`)**:
  - Tells guest OS the disk is an SSD
  - Enables optimizations (like disabling read-ahead)
  - Required for proper NVMe performance

- **Memory Ballooning (`--balloon 0`)**:
  - Disabled because Talos doesn't support it
  - Ensures VM always has full memory allocation

- **VirtIO SCSI Single**:
  - Paravirtualized SCSI controller
  - Better performance than emulated IDE/SATA
  - Required for discard/TRIM support

### Storage Layout Result

After creation:

```
nvme0n1 (local-lvm):
  ├─ puck-cp-01:      50GB  (VM 500, scsi0)
  ├─ puck-worker-01:  50GB  (VM 510, scsi0)
  └─ Free:           ~900GB

nvme1n1 (sn770):
  ├─ puck-worker-01: 700GB  (VM 510, scsi1)
  ├─ windows:         80GB  (VM 520, scsi0, stopped)
  └─ Free:           ~220GB
```

---

## Verification

Check VM configurations:

```bash
# List all VMs
qm list

# View specific VM config
qm config 500
qm config 510

# Check disk allocation
pvesm status
```

Expected output for worker VM:
```
scsi0: local-lvm:vm-510-disk-0,discard=on,size=50G,ssd=1
scsi1: sn770:vm-510-disk-1,discard=on,size=700G,ssd=1
cores: 9
cpu: host
memory: 43008
agent: enabled=1
```

---

## Next Steps

After VMs are created:

1. Boot VMs from Talos ISO
2. Generate Talos machine configs (see `recipe.md`)
3. For worker: Add second disk mount in machine config (see `hack/worker-two-disks.md`)
4. Apply configs with `talosctl apply-config`
5. Bootstrap cluster with `talosctl bootstrap`
6. Install Flux and point at this repo

---

## Troubleshooting

### VM won't start
- Check disk exists: `qm config <vmid>`
- Verify ISO attached: `qm config <vmid> | grep ide2`
- Check Proxmox logs: `journalctl -u pve-guests`

### Poor disk performance
- Ensure `discard=on` and `ssd=1` are set
- Check cache mode is "Default" or "none" (not writethrough/writeback)
- Verify both NVMe drives are healthy: `smartctl -a /dev/nvme0n1`

### QEMU agent not working
- Install qemu-guest-agent in guest OS (Talos includes it)
- Restart VM after enabling agent
- Check status: `qm agent 500 ping`
