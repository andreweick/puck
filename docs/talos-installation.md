# Talos Installation Guide

Step-by-step installation for puck cluster on Proxmox VE.

## Network Configuration

- **Control Plane**: puck-cp-01.spouterinn.org (10.200.10.50, VM 500)
- **Worker**: puck-worker-01.spouterinn.org (10.200.10.55, VM 510)
- **Tailnet**: tail4bbba.ts.net
- **Cluster Name**: puck
- **Cluster Endpoint**: https://puck-cp-01.spouterinn.org:6443

## Prerequisites

- VMs created and booted from Talos ISO (see `docs/pve-initial-setup.md`)
- DHCP reservations set for stable IPs
- DNS records configured (puck-cp-01.spouterinn.org, puck-worker-01.spouterinn.org)
- `talosctl` installed on your workstation

### Install talosctl (if needed)

```bash
# macOS
brew install siderolabs/tap/talosctl

# Linux
curl -sL https://talos.dev/install | sh

# Verify
talosctl version
```

### Configure talosctl config location

```bash
# Add to your ~/.zshrc or ~/.bashrc
export TALOSCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/talos/config"

# Reload shell config
source ~/.zshrc  # or source ~/.bashrc

# Create directory
mkdir -p ~/.config/talos
```

## Step 1: Generate Machine Configs

Generate the base configuration for your cluster:

```bash
cd /Users/maeick/code/puck

# Generate configs with DNS endpoint
talosctl gen config puck https://puck-cp-01.spouterinn.org:6443 \
  --output-dir ./talos-configs \
  --with-docs=false \
  --with-examples=false

# This creates:
# ./talos-configs/controlplane.yaml
# ./talos-configs/worker.yaml
# ./talos-configs/talosconfig
```

### Important: Save talosconfig

```bash
# If you have an old 'puck' context, remove it first
talosctl config contexts  # List all contexts
talosctl config remove puck  # Remove old context if it exists

# Merge the new talosconfig
talosctl config merge ./talos-configs/talosconfig

# Set the context to puck
talosctl config context puck

# Add endpoints (the nodes talosctl can connect to)
talosctl config endpoint puck-cp-01.spouterinn.org puck-worker-01.spouterinn.org

# Set default nodes (used when -n flag is omitted)
talosctl config node puck-cp-01.spouterinn.org puck-worker-01.spouterinn.org

# Verify configuration
talosctl config info
```

Expected output from `talosctl config info`:
```
Current context:  puck
Endpoints:        puck-cp-01.spouterinn.org, puck-worker-01.spouterinn.org
Nodes:            puck-cp-01.spouterinn.org, puck-worker-01.spouterinn.org
```

## Step 2: Customize Control Plane Config - Certificate SANs

Edit `./talos-configs/controlplane.yaml` to add certificate Subject Alternative Names (SANs).

### What are Certificate SANs?

**SANs define what hostnames/IPs the TLS certificates are valid for.** This allows you to connect to your cluster using different methods (DNS, IP, Tailscale) without certificate errors.

When Kubernetes/Talos generates a certificate, it says "this certificate is valid for these names: X, Y, Z". If you try to connect using a name that's NOT in the list, you get a certificate error.

**Example**: If you generate certs only for `10.200.10.50`, then later try to connect via `puck-cp-01.spouterinn.org`, you'll get an error: "certificate is valid for 10.200.10.50, not puck-cp-01.spouterinn.org".

### Two Separate Certificates in Talos

There are **two separate certificate locations** in Talos:

1. **`machine.certSANs`** - For the Talos API (port 50000, used by `talosctl`)
   - Used when you run: `talosctl version`, `talosctl dashboard`, etc.

2. **`cluster.apiServer.certSANs`** - For the Kubernetes API (port 6443, used by `kubectl`)
   - Used when you run: `kubectl get nodes`, `kubectl apply -f`, etc.

### Add these SANs to your controlplane.yaml:

Find the `machine` section and update it:

```yaml
machine:
    network:
        hostname: puck-cp-01
    certSANs:
        - puck-cp-01.spouterinn.org    # DNS name
        - 10.200.10.50                  # IP address
        - puck-cp-01                    # Tailscale MagicDNS short name
        - puck-cp-01.tail4bbba.ts.net   # Tailscale full domain
```

And further down in the `cluster` section:

```yaml
cluster:
    apiServer:
        certSANs:
            - puck-cp-01.spouterinn.org    # DNS name
            - 10.200.10.50                  # IP address
            - puck-cp-01                    # Tailscale MagicDNS short name
            - puck-cp-01.tail4bbba.ts.net   # Tailscale full domain
```

**Your config at `talos-configs/controlplane.yaml` has already been updated with these values!**

### Why include all these SANs?

- **DNS name** (`puck-cp-01.spouterinn.org`): Primary access method on your local network
- **IP address** (`10.200.10.50`): Fallback if DNS fails
- **Tailscale short name** (`puck-cp-01`): Quick access via Tailscale MagicDNS
- **Tailscale full name** (`puck-cp-01.tail4bbba.ts.net`): Access from anywhere on your tailnet

This allows you to run commands like:
```bash
# All of these will work without certificate errors:
talosctl --nodes puck-cp-01.spouterinn.org version
talosctl --nodes 10.200.10.50 version
talosctl --nodes puck-cp-01 version  # via Tailscale
talosctl --nodes puck-cp-01.tail4bbba.ts.net version  # via Tailscale
```

## Step 3: Customize Worker Config

Edit `./talos-configs/worker.yaml` - **this has already been updated for you!**

The worker config includes:

```yaml
machine:
    certSANs:
        - puck-worker-01.spouterinn.org
        - 10.200.10.55
        - puck-worker-01
        - puck-worker-01.tail4bbba.ts.net
    network:
        hostname: puck-worker-01
    disks:
        - device: /dev/sdb  # Second disk (scsi1, 700GB on sn770)
          partitions:
              - mountpoint: /var/mnt/data
```

### What this does:

- **certSANs**: Allows you to access the worker via DNS, IP, or Tailscale
- **hostname**: Sets the node name to `puck-worker-01` (shows up in `kubectl get nodes`)
- **disks**: Mounts your 700GB NVMe to `/var/mnt/data` which local-path-provisioner uses

## Step 4: Apply Configurations

Apply the machine configs to each node:

```bash
# Apply to control plane (using DNS name)
talosctl apply-config \
  --insecure \
  --nodes puck-cp-01.spouterinn.org \
  --file ./talos-configs/controlplane.yaml

# Apply to worker (using DNS name)
talosctl apply-config \
  --insecure \
  --nodes puck-worker-01.spouterinn.org \
  --file ./talos-configs/worker.yaml
```

The nodes will reconfigure and reboot. Wait 2-3 minutes for them to come back online.

### Verify nodes are ready

```bash
# Check control plane
talosctl --nodes puck-cp-01.spouterinn.org version
talosctl --nodes puck-cp-01.spouterinn.org dashboard

# Check worker
talosctl --nodes puck-worker-01.spouterinn.org version

# Verify worker's second disk is mounted
talosctl --nodes puck-worker-01.spouterinn.org list /var/mnt/data
talosctl --nodes puck-worker-01.spouterinn.org mounts | grep /var/mnt/data
```

Expected output for `mounts`:
```
puck-worker-01.spouterinn.org   /dev/sdb1    751.25     14.42      736.83          1.92%          /var/mnt/data
```

## Step 5: Bootstrap Kubernetes

Bootstrap etcd on the control plane:

```bash
# Bootstrap the cluster (using DNS name)
talosctl bootstrap --nodes puck-cp-01.spouterinn.org

# Wait for Kubernetes to start (2-3 minutes)
talosctl --nodes puck-cp-01.spouterinn.org health --wait-timeout 10m
```

## Step 6: Get kubeconfig

```bash
# Retrieve kubeconfig (using DNS name)
talosctl --nodes puck-cp-01.spouterinn.org kubeconfig ~/.kube/config

# Or merge with existing kubeconfig
talosctl --nodes puck-cp-01.spouterinn.org kubeconfig --merge

# Set context
kubectl config use-context admin@puck

# Verify cluster
kubectl get nodes
```

Expected output:
```
NAME             STATUS   ROLES           AGE   VERSION
puck-cp-01       Ready    control-plane   5m    v1.34.1
puck-worker-01   Ready    <none>          5m    v1.34.1
```

### Verify storage is available

```bash
# Check that /var/mnt/data is mounted on worker
talosctl --nodes puck-worker-01.spouterinn.org mounts | grep /var/mnt/data

# Should see:
# puck-worker-01.spouterinn.org   /dev/sdb1    751.25     14.42      736.83          1.92%          /var/mnt/data
```

## Step 7: Setup SOPS for Secrets

Before installing Flux, set up SOPS encryption:

```bash
cd /Users/maeick/code/puck

# Generate age key (if you haven't already)
age-keygen -o age.key

# The output shows your public key:
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Update .sops.yaml with your PUBLIC key
# (Replace the placeholder in the file)
```

Edit `.sops.yaml` and replace the placeholder:
```yaml
creation_rules:
  - path_regex: secret\..*\.yaml$
    age: >-
      age1YOUR_PUBLIC_KEY_HERE
```

Create the SOPS secret in Kubernetes:

```bash
# Create flux-system namespace
kubectl create namespace flux-system

# Create the SOPS age secret
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=./age.key

# Verify
kubectl -n flux-system get secret sops-age
```

**IMPORTANT: Back up `age.key` securely!** Without it, you can't decrypt your secrets.

## Step 8: Prepare for Gradual Deployment

### Architecture Overview

Your cluster implements a **Zero Trust** architecture where all services (except LAN-only) are accessed through Cloudflare:

**Standard Access** (All Services via Cloudflare):
```
Any Device (home/remote) → Cloudflare Edge → Cloudflare Tunnel → Caddy → Services
                              ↓
                         Zero Trust:
                         - Identity (OAuth/email)
                         - Access policies
                         - Optional: device posture

Services: gordie, ups, jackie2, pudge, photos
```

**LAN-Only Access** (Jellyfin Exception):
```
Local Device → Internal DNS → 10.200.10.99 (VIP) → Caddy → Jellyfin
                                                    ✗ Not via Cloudflare (ToS violation)
```

**Key Principles:**
- No split-horizon DNS (same URLs everywhere)
- No direct internet exposure (all via Cloudflare)
- Authenticated Origin Pulls prevent bypass
- Single source of authentication (Cloudflare Access)

### Deployment Order

The recommended order is:
1. **Cloudflare Tunnel first** - For secure external access with authentication
2. **kube-vip** - For LoadBalancer support (VIP for services)
3. **Essential infrastructure** - CNI, storage, ingress (Caddy)
4. **Applications** - Databases, then apps like Immich

### Files Already Modified (Ready to Use)

✅ `infra/kube-vip/daemonset.yaml` - VIP: 10.200.10.99, LoadBalancer enabled
✅ `infra/kustomization.yaml` - kube-vip enabled
✅ `infra/ingress/caddyfile-gateway/deploy-svc.yaml` - Changed to LoadBalancer
✅ `infra/ingress/caddyfile-gateway/caddy-configmap.yaml` - All services configured
✅ `apps/kustomization.yaml` - Cloudflared marked as "ENABLE THIS FIRST"

### Step 8a: Configure Cloudflare Zero Trust Access (Do This First!)

This setup implements a Zero Trust architecture where ALL services (except LAN-only) are accessed through Cloudflare. No split DNS, no direct access to your cluster from the internet.

#### Architecture Overview

**Access Pattern:**
```
User → Cloudflare Edge (Zero Trust checks) → Cloudflare Tunnel → Caddy → Services
         ↓
    - Identity verification (email/OAuth)
    - Optional device posture (WARP)
    - Authenticated Origin Pulls (validates traffic is from CF)
```

**LAN-Only Exception (Jellyfin):**
```
Local Device → Internal DNS → 10.200.10.99 (kube-vip VIP) → Jellyfin
```

**Key Principle:** Everything goes through Cloudflare (except Jellyfin). No split-horizon DNS for the same service.

#### Phase 1: Create Cloudflare Tunnel

1. **Create a Cloudflare Tunnel**:
   ```bash
   # Go to Cloudflare Zero Trust dashboard
   # https://one.dash.cloudflare.com/
   # Navigate to: Networks → Tunnels
   # Click "Create a tunnel"
   # Choose "Cloudflared" connector
   # Name it: "puck-cluster"
   # Install connector: Choose "Docker"
   # Copy the token (starts with eyJ...)
   ```

2. **Create the tunnel secret**:
   ```bash
   # Create the secret file
   cat > apps/dmz/cloudflared/secret.tunnel-token.yaml <<EOF
   apiVersion: v1
   kind: Secret
   metadata:
     name: tunnel-token
     namespace: cloudflared
   type: Opaque
   stringData:
     token: "YOUR_TUNNEL_TOKEN_HERE"
   EOF

   # Encrypt with SOPS
   sops -e -i apps/dmz/cloudflared/secret.tunnel-token.yaml

   # Verify it's encrypted
   cat apps/dmz/cloudflared/secret.tunnel-token.yaml | head -5
   ```

3. **Configure tunnel routes in Cloudflare dashboard**:

   In the Cloudflare Tunnels dashboard, add these public hostnames:

   | Public hostname | Service | Path | Notes |
   |----------------|---------|------|-------|
   | `gordie.spouterinn.org` | `http://caddy-gateway.ingress:8080` | `/` | Proxmox VE |
   | `ups.spouterinn.org` | `http://caddy-gateway.ingress:8080` | `/` | UPS management |
   | `jackie2.spouterinn.org` | `http://caddy-gateway.ingress:8080` | `/` | Synology NAS |
   | `pudge.spouterinn.org` | `http://caddy-gateway.ingress:8080` | `/` | Synology NAS |
   | `photos.organmorgan.org` | `http://caddy-gateway.ingress:8080` | `/` | Immich (when deployed) |

   **Do NOT add**: `jellyfin.spouterinn.org` (violates CF ToS for video streaming - LAN-only)

   **Important**: The service should be `http://caddy-gateway.ingress:8080` (the Kubernetes service name and port that Caddy listens on inside the cluster).

#### Phase 2: Configure Cloudflare Access (Zero Trust Authentication)

We'll configure OAuth/OIDC SSO for all services that support it, providing seamless single sign-on. Only the UPS (which doesn't support OAuth) will use front-door email authentication.

##### 2a. Proxmox (gordie.spouterinn.org) - OAuth/OIDC SSO

Proxmox VE supports OpenID Connect, providing full SSO capability:

1. **Create Access Application**:
   ```
   In Cloudflare Zero Trust Dashboard:
   - Navigate to: Access → Applications
   - Click "Add an application"
   - Choose: "SaaS application"

   Application Configuration:
   - Application name: "Proxmox VE (gordie)"
   - Session duration: 24 hours
   - Application type: "OIDC"
   - Redirect URLs: https://gordie.spouterinn.org:8006

   Note the:
   - Client ID
   - Client Secret
   - Issuer (e.g., https://YOUR-TEAM.cloudflareaccess.com)
   - OIDC endpoint: https://YOUR-TEAM.cloudflareaccess.com/cdn-cgi/access/callback
   ```

2. **Add Policy**:
   ```
   Policy name: "Proxmox Admins"
   Action: Allow

   Include:
   - Emails: your-email@example.com

   (Add additional admin emails as needed)
   ```

3. **Configure Proxmox VE OpenID Connect**:

   Log into Proxmox (gordie):
   ```
   Datacenter → Permissions → Realms → Add → OpenID Connect Server

   Issuer URL: https://YOUR-TEAM.cloudflareaccess.com
   Realm: cloudflare
   Client ID: (Client ID from step 1)
   Client Key: (Client Secret from step 1)
   Username Claim: email
   Scopes: openid email profile
   Autocreate Users: Yes (optional - auto-creates users on first login)

   Default: No (keep PVE authentication as fallback)
   Comment: Cloudflare Access SSO
   ```

4. **Create Proxmox User with cloudflare realm**:
   ```
   Datacenter → Permissions → Users → Add

   User name: your-email@example.com
   Realm: cloudflare
   Group: (assign appropriate group, e.g., admins)

   Then assign permissions:
   Datacenter → Permissions → Add → User Permission
   Path: /
   User: your-email@example.com@cloudflare
   Role: Administrator (or appropriate role)
   ```

5. **Test SSO Login**:
   - Browse to https://gordie.spouterinn.org
   - Cloudflare Access prompts for login
   - After authentication, Proxmox login page appears
   - Select "cloudflare" realm from dropdown
   - Click "Login" button (should auto-login with SSO!)

**Troubleshooting:**
- If auto-login doesn't work, verify the redirect URL matches exactly
- Check Proxmox logs: `journalctl -u pveproxy -f`
- Verify user exists in Proxmox with the correct realm
- Ensure user has appropriate permissions

##### 2b. Synology DSM (jackie2.spouterinn.org, pudge.spouterinn.org) - OAuth/OIDC

Synology DSM supports OAuth, providing SSO:

1. **Create Access Application for jackie2**:
   ```
   In Cloudflare Zero Trust Dashboard:
   - Navigate to: Access → Applications
   - Click "Add an application"
   - Choose: "SaaS application"

   Application Configuration:
   - Application name: "Synology jackie2"
   - Session duration: 24 hours
   - Application type: "OIDC"
   - Redirect URLs: https://jackie2.spouterinn.org/

   Note the:
   - Client ID
   - Client Secret
   - Issuer (e.g., https://YOUR-TEAM.cloudflareaccess.com)
   ```

2. **Add Policy**:
   ```
   Policy name: "NAS Users"
   Action: Allow

   Include:
   - Emails: your-email@example.com, family@example.com
   ```

3. **Configure Synology DSM**:
   ```
   Log into DSM (jackie2):
   - Control Panel → Domain/LDAP → SSO Client
   - Click "Set up a new SSO server"
   - Choose: OpenID Connect

   Settings:
   - Profile name: Cloudflare Access
   - Well-known URL: https://YOUR-TEAM.cloudflareaccess.com/.well-known/openid-configuration
   - Application ID: (Client ID from step 1)
   - Application key: (Client Secret from step 1)
   - Redirect URL: https://jackie2.spouterinn.org/
   - Username claim: email

   - Enable: "Set as default"
   - Apply
   ```

4. **Repeat for pudge**:
   - Create separate Access Application for "Synology pudge"
   - Use hostname: pudge.spouterinn.org
   - Configure DSM on pudge with its own Client ID/Secret

##### 2c. UPS (ups.spouterinn.org) - Front-Door Protection Only

The UPS web interface doesn't support OAuth, so we protect it at the Cloudflare edge:

1. **Create Access Application**:
   ```
   In Cloudflare Zero Trust Dashboard:
   - Navigate to: Access → Applications
   - Click "Add an application"
   - Choose: "Self-hosted"

   Application Configuration:
   - Application name: "UPS Management"
   - Session duration: 24 hours
   - Application domain: ups.spouterinn.org
   ```

2. **Add Policy**:
   ```
   Policy name: "Admin Access"
   Action: Allow

   Include:
   - Emails: your-email@example.com
   ```

3. **User Experience**:
   - User browses to https://ups.spouterinn.org
   - Cloudflare prompts for email login
   - After authentication, user sees UPS interface
   - UPS's built-in login is still there but less critical (defense in depth)

#### Phase 3: Enable Authenticated Origin Pulls (Recommended)

This prevents anyone from bypassing Cloudflare and connecting directly to your cluster.

1. **Download Cloudflare Origin Pull Certificate**:
   ```bash
   # On your workstation
   curl -o /tmp/cloudflare-origin-pull-ca.pem \
     https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem
   ```

2. **Create Kubernetes Secret**:
   ```bash
   kubectl -n ingress create secret generic cloudflare-origin-ca \
     --from-file=ca.crt=/tmp/cloudflare-origin-pull-ca.pem
   ```

3. **Update Caddy Deployment** (future step - manual for now):

   You'll need to mount this certificate and configure Caddy to require it. We'll document this in a separate step after basic setup is working.

4. **Enable in Cloudflare Dashboard**:
   ```
   Go to: SSL/TLS → Origin Server → Authenticated Origin Pulls
   - Toggle "Authenticated Origin Pulls" to ON

   Note: Only enable this AFTER Caddy is configured to accept the certificate,
   otherwise all requests will fail!
   ```

#### Phase 4: Testing Access

After completing the above steps, test each service:

1. **From your browser** (anywhere with internet):
   ```
   https://gordie.spouterinn.org   → Should prompt for email, then show Proxmox
   https://jackie2.spouterinn.org  → Should SSO with Cloudflare, then show DSM
   https://pudge.spouterinn.org    → Should SSO with Cloudflare, then show DSM
   https://ups.spouterinn.org      → Should prompt for email, then show UPS interface
   ```

2. **Verify Cloudflare Tunnel is working**:
   ```bash
   # Check cloudflared is running
   kubectl -n cloudflared get pods
   kubectl -n cloudflared logs deploy/cloudflared | grep "Connection registered"
   ```

3. **Verify Caddy is accessible from cloudflared**:
   ```bash
   kubectl -n cloudflared exec deploy/cloudflared -- \
     curl -H "Host: gordie.spouterinn.org" http://caddy-gateway.ingress:8080
   ```

#### Understanding the Access Flow

**For OAuth/OIDC-enabled services (Proxmox, Synology, Immich):**
```
1. User → https://gordie.spouterinn.org (or jackie2, pudge, photos)
2. Cloudflare Access → "Please log in"
3. User logs in (email, Google, GitHub, etc.)
4. Cloudflare validates → sets auth cookie
5. Cloudflare Tunnel → forwards to Caddy
6. Caddy → reverse proxy to backend service
7. Backend service sees OAuth token → auto-login (SSO!)
   - No need to enter password again!
```

**For non-OAuth services (UPS only):**
```
1. User → https://ups.spouterinn.org
2. Cloudflare Access → "Please log in"
3. User logs in (email verification)
4. Cloudflare validates → sets auth cookie
5. Cloudflare Tunnel → forwards to Caddy
6. Caddy → reverse proxy to UPS
7. UPS shows its own login screen (but already protected by CF)
   - Defense in depth: CF protects at edge, UPS has its own auth
```

#### Phase 5: CLI and Automation Access

The above phases handle **human users** accessing services through browsers. For **CLI tools, scripts, and automation**, you need different authentication methods since they can't handle OAuth redirects.

##### Understanding CLI Authentication Options

**The Challenge:**
```
Browser:  Can handle redirects, cookies, JavaScript ✅
CLI Tool: Just wants to make API calls ❌
```

**Three Solutions:**

1. **Service Tokens (Headers)** - Best for most automation
   - Cloudflare generates token pairs (ID + Secret)
   - Pass as HTTP headers with each request
   - Each token is unique (NOT your user ID!)
   - Ideal for: Scripts, CI/CD, cron jobs

2. **mTLS (Client Certificates)** - Best for long-running daemons
   - Client presents certificate to prove identity
   - No headers or tokens in environment variables
   - Harder to accidentally leak
   - Ideal for: Database tools, monitoring, backup daemons

3. **WARP Client** - Transparent device authentication
   - Install Cloudflare WARP on the machine
   - Device gets authenticated
   - All traffic from that device is trusted
   - Ideal for: Developer workstations, jump hosts

##### Decision Tree: Which Method to Use?

```
Does the tool support custom HTTP headers?
├── YES → Use Service Tokens (easiest to set up)
│         Examples: curl, wget, rclone, restic
│
└── NO
    ├── Does it support TLS client certificates?
    │   ├── YES → Use mTLS
    │   │         Examples: psql, pg_dump, mysql, monitoring tools
    │   │
    │   └── NO → Use WARP client for transparent access
    │             Examples: Legacy tools, complex applications
```

##### 5a. Service Tokens for Automation

**Important:** Each Service Token is a unique ID/Secret pair. It is **NOT** your Cloudflare user ID!

**Creating Service Tokens:**

1. **In Cloudflare Zero Trust Dashboard:**
   ```
   Navigate to: Access → Service Auth → Service Tokens
   Click: "Create Service Token"

   Name: "backup-scripts"  (descriptive name for this token's purpose)
   Service Token Duration: 1 year (or shorter for security)

   Copy both values:
   - Client ID: abc123def456...  (unique for this token)
   - Client Secret: xyz789uvw012...  (unique for this token)

   IMPORTANT: The Client Secret is only shown once! Save it securely.
   ```

2. **Update Access Policies to Allow Service Tokens:**
   ```
   Go to your Access Application (e.g., "Proxmox VE")
   Edit Policy → Include

   Add rule:
   - Selector: "Service Auth"
   - Value: "backup-scripts" (the token name you created)
   ```

**Using Service Tokens with Tools:**

```bash
# Example 1: curl
curl -H "CF-Access-Client-Id: abc123def456..." \
     -H "CF-Access-Client-Secret: xyz789uvw012..." \
     https://gordie.spouterinn.org/api/endpoint

# Example 2: rclone (for backups)
rclone sync /data remote:backup \
  --header "CF-Access-Client-Id: abc123def456..." \
  --header "CF-Access-Client-Secret: xyz789uvw012..."

# Example 3: In a script with environment variables
export CF_ACCESS_CLIENT_ID="abc123def456..."
export CF_ACCESS_CLIENT_SECRET="xyz789uvw012..."

curl -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
     -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
     https://gordie.spouterinn.org/api/data
```

**Service Token Best Practices:**
- Create separate tokens for different purposes (backup, monitoring, CI/CD)
- Set expiration dates and rotate before expiry
- Store in secrets manager (not in code!)
- Revoke immediately if compromised
- Use descriptive names to track usage

##### 5b. mTLS (Client Certificates) for Database Tools

For tools like `pg_dump`, `psql`, `mysql` that don't support custom headers but do support TLS client certificates.

**Certificate Strategy:**

Recommended approach:
- **One certificate per application/daemon** - Best security, easy revocation
- Alternative: **One certificate per cluster node** - Simpler management
- Avoid: **One certificate for everything** - Too risky if compromised

**Option 1: Using Cloudflare mTLS (Recommended)**

1. **Enable mTLS in Cloudflare Access:**
   ```
   Zero Trust → Access → Applications → [Your App]
   Settings → mTLS authentication

   Upload CA Certificate:
   - Upload your CA's public certificate
   - Cloudflare will validate client certs signed by this CA
   ```

2. **Generate Client Certificates:**
   ```bash
   # On your workstation or certificate authority

   # Generate CA (if you don't have one)
   openssl genrsa -out ca.key 4096
   openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
     -subj "/CN=Puck Cluster CA/O=Homelab"

   # Generate client certificate for pg_dump
   openssl genrsa -out pgdump-client.key 2048
   openssl req -new -key pgdump-client.key -out pgdump-client.csr \
     -subj "/CN=pg-backup-client/O=Homelab"

   # Sign with your CA
   openssl x509 -req -days 365 \
     -in pgdump-client.csr \
     -CA ca.crt -CAkey ca.key \
     -CAcreateserial -out pgdump-client.crt

   # Clean up CSR
   rm pgdump-client.csr
   ```

3. **Upload CA to Cloudflare:**
   ```
   In Cloudflare Zero Trust:
   Access → Applications → [Your Application] → Configure

   Under "mTLS authentication":
   - Upload ca.crt
   - Enable "Require valid certificate"
   ```

4. **Update Access Policy:**
   ```
   Edit Access Policy → Include
   Add rule:
   - Selector: "Valid Certificate"
   - (Certificate validation happens automatically)
   ```

**Option 2: Using Authenticated Origin Pulls with mTLS**

This requires configuring Caddy to validate client certificates (more advanced).

##### 5c. Example: PostgreSQL Backup with mTLS

**Scenario:** You have a PostgreSQL database backup running in your cluster that needs to backup to an external S3 bucket protected by Cloudflare Access.

**Setup:**

1. **Create client certificate** (as shown above)

2. **Create Kubernetes Secret with certificate:**
   ```bash
   kubectl -n backup create secret generic pgdump-mtls-cert \
     --from-file=client.crt=pgdump-client.crt \
     --from-file=client.key=pgdump-client.key
   ```

3. **Configure pg_dump to use certificate:**
   ```bash
   # In your backup script or CronJob

   # Copy certs from secret mount
   cp /etc/pgdump-certs/client.crt /tmp/client.crt
   cp /etc/pgdump-certs/client.key /tmp/client.key
   chmod 600 /tmp/client.key

   # PostgreSQL connection with SSL client cert
   pg_dump \
     "host=postgres.work.svc.cluster.local \
      port=5432 \
      dbname=mydb \
      user=backup \
      sslmode=require \
      sslcert=/tmp/client.crt \
      sslkey=/tmp/client.key" \
     | gzip > /backup/mydb-$(date +%Y%m%d).sql.gz
   ```

4. **CronJob example:**
   ```yaml
   apiVersion: batch/v1
   kind: CronJob
   metadata:
     name: postgres-backup
     namespace: backup
   spec:
     schedule: "0 2 * * *"  # 2 AM daily
     jobTemplate:
       spec:
         template:
           spec:
             containers:
             - name: pg-backup
               image: postgres:16
               command:
               - /bin/bash
               - -c
               - |
                 cp /etc/pgdump-certs/client.crt /tmp/client.crt
                 cp /etc/pgdump-certs/client.key /tmp/client.key
                 chmod 600 /tmp/client.key

                 pg_dump "host=${PG_HOST} port=5432 dbname=${PG_DB} user=backup \
                          sslmode=require sslcert=/tmp/client.crt sslkey=/tmp/client.key" \
                   | gzip > /backup/backup-$(date +%Y%m%d).sql.gz
               volumeMounts:
               - name: certs
                 mountPath: /etc/pgdump-certs
                 readOnly: true
               - name: backup-storage
                 mountPath: /backup
             volumes:
             - name: certs
               secret:
                 secretName: pgdump-mtls-cert
                 defaultMode: 0400
             - name: backup-storage
               persistentVolumeClaim:
                 claimName: backup-pvc
             restartPolicy: OnFailure
   ```

##### 5d. Example: Litestream with mTLS

**Litestream** (SQLite replication) supports mTLS natively:

```yaml
# litestream.yml
dbs:
  - path: /data/app.db
    replicas:
      - url: https://backup.example.com/litestream/app
        # mTLS authentication
        client-cert-path: /etc/litestream/client.crt
        client-key-path: /etc/litestream/client.key
```

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-litestream
spec:
  template:
    spec:
      containers:
      - name: litestream
        image: litestream/litestream:latest
        args: ["replicate"]
        volumeMounts:
        - name: litestream-config
          mountPath: /etc/litestream.yml
          subPath: litestream.yml
        - name: mtls-cert
          mountPath: /etc/litestream
          readOnly: true
        - name: data
          mountPath: /data
      volumes:
      - name: litestream-config
        configMap:
          name: litestream-config
      - name: mtls-cert
        secret:
          secretName: litestream-mtls-cert
          defaultMode: 0400
      - name: data
        persistentVolumeClaim:
          claimName: app-data-pvc
```

##### 5e. Certificate Rotation Strategy

**Best Practices:**

1. **Certificate Lifetimes:**
   - CA Certificate: 10 years (rarely rotated)
   - Client Certificates: 1 year (rotate annually)
   - For high-security: 90 days

2. **Rotation Process:**
   ```bash
   # 1. Generate new certificate (before old one expires)
   openssl genrsa -out pgdump-client-new.key 2048
   openssl req -new -key pgdump-client-new.key -out pgdump-client-new.csr \
     -subj "/CN=pg-backup-client/O=Homelab"
   openssl x509 -req -days 365 \
     -in pgdump-client-new.csr \
     -CA ca.crt -CAkey ca.key \
     -CAcreateserial -out pgdump-client-new.crt

   # 2. Update Kubernetes secret
   kubectl -n backup create secret generic pgdump-mtls-cert-new \
     --from-file=client.crt=pgdump-client-new.crt \
     --from-file=client.key=pgdump-client-new.key

   # 3. Update deployment to use new secret
   kubectl -n backup set volumes cronjob/postgres-backup \
     --add --name=certs --secret-name=pgdump-mtls-cert-new

   # 4. Test new certificate works
   # 5. Delete old secret
   kubectl -n backup delete secret pgdump-mtls-cert

   # 6. Rename new secret to standard name
   kubectl -n backup get secret pgdump-mtls-cert-new -o yaml | \
     sed 's/pgdump-mtls-cert-new/pgdump-mtls-cert/' | \
     kubectl apply -f -
   kubectl -n backup delete secret pgdump-mtls-cert-new
   ```

3. **Certificate Inventory:**
   Keep track of all certificates:
   ```
   Certificate Name      Purpose           Expires       Namespaces
   pgdump-client.crt    DB backups        2025-10-21    backup
   litestream.crt       SQLite replica    2025-10-21    dmz
   prometheus.crt       Metrics scraping  2025-10-21    monitoring
   ```

##### 5f. Service Tokens vs mTLS Comparison

| Feature | Service Tokens | mTLS Certificates |
|---------|---------------|-------------------|
| **Setup Complexity** | Easy | Moderate |
| **Security** | Good | Excellent |
| **Revocation** | Instant (via dashboard) | Requires cert revocation |
| **Storage** | Environment vars/secrets | Files mounted in pods |
| **Leak Risk** | Higher (headers visible) | Lower (encrypted channel) |
| **Best For** | Scripts, CI/CD | Daemons, databases |
| **Examples** | rclone, curl, restic | pg_dump, mysql, litestream |
| **Max Lifetime** | 1 year | Any (you control it) |

**When to use Service Tokens:**
- Short-lived scripts
- CI/CD pipelines
- Tools that support custom headers
- When you need easy rotation via dashboard

**When to use mTLS:**
- Long-running daemons
- Database connections
- Higher security requirements
- Tools that don't support custom headers

##### Summary: CLI Authentication Layers

```
Layer 1: Network Path
  Cloudflare Tunnel → Caddy → Service

Layer 2: Authentication (Choose based on tool)
  ├── Browser Users: OAuth/OIDC (Phase 2)
  ├── CLI with headers: Service Tokens (Phase 5a)
  └── CLI without headers: mTLS (Phase 5b)

Layer 3: Service-Level Auth (if applicable)
  Database credentials, API keys, etc.
```

All three layers work together to provide defense in depth while accommodating different client capabilities.

### Step 8b: Configure kube-vip for LoadBalancer Support

Enable kube-vip to provide LoadBalancer functionality:

kube-vip will provide a Virtual IP (VIP) that makes services accessible regardless of which worker node they run on.

**The configuration has already been updated with:**
- VIP address: `10.200.10.99`
- LoadBalancer range: `10.200.10.99-10.200.10.110`
- LoadBalancer support enabled

### Step 8c: Configure Caddy Reverse Proxy

The Caddy configuration has been prepared to proxy to your existing home network services:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: caddyfile
  namespace: ingress
data:
  Caddyfile: |
    :8080 {
      # Proxmox VE
      handle_host gordie.spouterinn.org {
        reverse_proxy https://10.200.10.40:8006 {
          transport http {
            tls_insecure_skip_verify
          }
        }
      }

      # UPS Management
      handle_host ups.spouterinn.org {
        reverse_proxy https://10.200.10.41 {
          transport http {
            tls_insecure_skip_verify
          }
        }
      }

      # Synology NAS
      handle_host jackie2.spouterinn.org {
        reverse_proxy http://10.200.10.44:5000
      }

      # Add more services as needed
      # handle_host myservice.spouterinn.org {
      #   reverse_proxy http://192.168.1.x:port
      # }
    }
```

**Note:** The `infra/ingress/caddyfile-gateway/deploy-svc.yaml` has been updated to use `type: LoadBalancer`, which will automatically get the VIP from kube-vip.

### Step 8d: Enable Workloads in Correct Order

The deployment order is important for dependencies:

1. **First, enable Cloudflare Tunnel** in `apps/kustomization.yaml`:
   ```yaml
   resources:
     - dmz/cloudflared    # Enable this FIRST for external access
   ```

2. **Then enable infrastructure** in `infra/kustomization.yaml`:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     # Uncomment these one at a time after core infrastructure is working
     # - dmz/immich
     # - dmz/cloudflared
     # - work/postgres
     # - work/minio
     # - dev/devbox
   ```

2. **Edit `infra/kustomization.yaml`** to start with essentials only:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - namespaces
     - cilium          # CNI (required)
     - local-path      # Storage (required)
     - policies        # Security policies
     - ingress         # Caddy reverse proxy
     - kube-vip        # LoadBalancer support (required for Caddy)
     # Uncomment these as needed:
     # - nfs-csi       # NFS storage (if needed)
     # - tailscale-apiserver  # Tailscale access (optional)
     # - cnpg          # PostgreSQL operator (needed before work/postgres)
     # - image-automation  # Flux image updates (optional)
     # - longhorn      # Alternative storage (optional)
   ```

### Configure Secrets

#### Tailscale API Server Auth Key (Optional)

If you want to enable Tailscale access to your cluster API server:

1. **Generate Tailscale Auth Key**:
   - Log into Tailscale admin console: https://login.tailscale.com/admin/settings/keys
   - Go to Settings → Keys
   - Click "Generate auth key"
   - Select options:
     - ✅ **Reusable** (allows multiple uses)
     - ✅ **Ephemeral** (optional, removes device when it goes offline)
     - Set expiration as needed
   - Copy the key (starts with `tskey-auth-...`)

2. **Update the Tailscale secret**:
   ```bash
   # Edit the secret in infra/tailscale-apiserver/ds-and-secret.yaml
   # Replace: TS_AUTHKEY: "tskey-REUSABLE-CHANGE-ME"
   # With:    TS_AUTHKEY: "tskey-auth-YOUR-ACTUAL-KEY"

   # Then encrypt the file with SOPS
   sops -e -i infra/tailscale-apiserver/ds-and-secret.yaml
   ```

3. **What this enables**:
   - Access Kubernetes API via Tailscale: `kubectl --server https://puck-api:6443 get nodes`
   - Access Talos API via Tailscale: `talosctl --nodes puck-api version`
   - Works from anywhere on your tailnet without exposing ports

#### Cloudflare Tunnel Token (Optional)

If you want external access via Cloudflare Tunnel:

1. **Create Cloudflare Tunnel**:
   - Log into Cloudflare Dashboard
   - Go to Zero Trust → Networks → Tunnels
   - Create a tunnel, name it (e.g., "puck-cluster")
   - Copy the tunnel token

2. **Store Cloudflare Secret**:
   ```bash
   # Create the secret file
   cat > apps/dmz/cloudflared/secret.tunnel-token.yaml <<EOF
   apiVersion: v1
   kind: Secret
   metadata:
     name: cloudflare-tunnel-token
     namespace: dmz
   type: Opaque
   stringData:
     token: YOUR_CLOUDFLARE_TUNNEL_TOKEN_HERE
   EOF

   # Encrypt with SOPS
   sops -e -i apps/dmz/cloudflared/secret.tunnel-token.yaml
   ```

#### Configure DNS - Zero Trust Setup (No Split Horizon)

With Zero Trust architecture, there's **no split DNS** for most services. Everything goes through Cloudflare.

**External DNS (in Cloudflare - Automatic):**
When you configure the Cloudflare Tunnel public hostnames, Cloudflare automatically creates DNS records:
- The tunnel creates CNAME records pointing to your tunnel URL
- These work from anywhere (inside your network or external)
- No additional configuration needed

**Internal DNS (on your router/PiHole) - LAN-ONLY Services:**
Only configure internal DNS for services that should NOT go through Cloudflare:

```
# Only Jellyfin is LAN-only (Cloudflare ToS violation)
jellyfin.spouterinn.org   A  10.200.10.99

# Or use a .local/.home domain for clarity:
jellyfin.home             A  10.200.10.99
```

**Do NOT add internal DNS for:**
- gordie.spouterinn.org (goes through Cloudflare)
- ups.spouterinn.org (goes through Cloudflare)
- jackie2.spouterinn.org (goes through Cloudflare)
- pudge.spouterinn.org (goes through Cloudflare)
- photos.organmorgan.org (goes through Cloudflare)

**Why No Split DNS?**
- **Simpler**: One access path for each service
- **Consistent**: Same URLs work everywhere
- **Secure**: Can't bypass Cloudflare authentication
- **Better UX**: No confusion about which DNS to use

**Access Patterns:**
```
From Home Network:
  User → Cloudflare (via public DNS) → Tunnel → Caddy → Service
  (Same as external access - consistent!)

From Internet:
  User → Cloudflare (via public DNS) → Tunnel → Caddy → Service
  (Identical flow)

Jellyfin (Exception):
  User on LAN → Internal DNS (10.200.10.99) → kube-vip → Caddy → Jellyfin
  (Not accessible from internet)
```

**Testing Before Cloudflare Tunnel is Configured:**

If you want to test Caddy before setting up Cloudflare Tunnel:
```bash
# Temporarily add to /etc/hosts on your workstation:
10.200.10.99 gordie.spouterinn.org ups.spouterinn.org jackie2.spouterinn.org pudge.spouterinn.org

# Test with curl:
curl -H "Host: gordie.spouterinn.org" http://10.200.10.99:8080

# Remove these entries once Cloudflare Tunnel is working!
```

## Step 9: Install Flux

### Pre-flight Checklist

Before bootstrapping Flux, ensure you've:
- [ ] Created and encrypted Cloudflare tunnel secret (`apps/dmz/cloudflared/secret.tunnel-token.yaml`)
- [ ] Configured tunnel routes in Cloudflare dashboard
- [ ] Set up Cloudflare Access policies for internal services
- [ ] Enabled `dmz/cloudflared` in `apps/kustomization.yaml`
- [ ] Verified kube-vip is enabled in `infra/kustomization.yaml`
- [ ] Updated Caddy service to `type: LoadBalancer`
- [ ] Committed all changes to Git

### Bootstrap Flux

```bash
# Install Flux CLI (if needed)
brew install fluxcd/tap/flux  # macOS
# OR
curl -s https://fluxcd.io/install.sh | sudo bash  # Linux

# Check prerequisites
flux check --pre

# Bootstrap Flux (replace with your GitHub details)
flux bootstrap github \
  --owner=YOUR_GITHUB_USERNAME \
  --repository=puck \
  --branch=main \
  --path=clusters/prod \
  --personal

# If you haven't pushed to GitHub yet:
git add .
git commit -m "Configure Cloudflare Tunnel, kube-vip, and Caddy for gradual deployment"
git remote add origin https://github.com/YOUR_USERNAME/puck.git
git push -u origin main

# Then run the bootstrap command
```

### Alternative: Manual Flux Installation

If you don't want GitHub integration yet:

```bash
# Install Flux components
flux install

# Create GitRepository source
flux create source git flux-system \
  --url=https://github.com/YOUR_USERNAME/puck \
  --branch=main \
  --interval=1m

# Create Kustomization pointing to clusters/prod
kubectl apply -f clusters/prod/ks.yaml
```

## Step 10: Verify Initial Deployment

Watch Flux reconcile your infrastructure and verify services are running:

### Check Deployment Order

```bash
# 1. Verify Flux is working
flux get sources git
flux get kustomizations --watch

# 2. Check Cloudflare Tunnel is running FIRST
kubectl -n cloudflared get pods
kubectl -n cloudflared logs deploy/cloudflared

# You should see: "Connection registered" in the logs

# 3. Verify kube-vip is providing LoadBalancer
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-vip
kubectl -n kube-system logs -l app.kubernetes.io/name=kube-vip

# 4. Check Caddy got its LoadBalancer IP
kubectl -n ingress get svc caddy-gateway
# Should show EXTERNAL-IP as 10.200.10.99

# 5. Verify core infrastructure
kubectl get pods -n kube-system  # Cilium, CoreDNS, kube-vip
kubectl get pods -n ingress      # Caddy

# 6. Test connectivity
# Internal (from your local network):
curl -H "Host: gordie.spouterinn.org" http://10.200.10.99
curl -H "Host: ups.spouterinn.org" http://10.200.10.99

# External (from internet):
# Browse to https://gordie.spouterinn.org
# Should prompt for Cloudflare Access login
```

### Troubleshooting Flux

```bash
# Check Flux logs
flux logs --level=error

# Force reconciliation
flux reconcile kustomization infra
flux reconcile kustomization apps

# Check specific resource
kubectl describe helmrelease cilium -n kube-system
```

## Step 11: Gradual Application Deployment

After the core infrastructure is running stable, you can gradually enable applications:

### Deployment Order

1. **First Wave - Database Infrastructure**:
   ```bash
   # Uncomment in infra/kustomization.yaml:
   # - cnpg

   # Commit and push
   git add infra/kustomization.yaml
   git commit -m "Enable CNPG PostgreSQL operator"
   git push

   # Wait for it to be ready
   flux get kustomization infra
   kubectl -n cnpg-system get pods
   ```

2. **Second Wave - Storage and Databases**:
   ```bash
   # Uncomment in apps/kustomization.yaml:
   # - work/postgres
   # - work/minio

   # Create required secrets first (see below)
   # Then commit and push
   ```

3. **Third Wave - Applications**:
   ```bash
   # Uncomment in apps/kustomization.yaml:
   # - dmz/immich

   # After it's working, add:
   # - dmz/cloudflared  # For external access
   # - dev/devbox       # Development environment
   ```

### Testing Zero Trust Access

Once Cloudflare Tunnel and Access are configured, test access:

#### Testing from Anywhere (Home or Remote):
```bash
# All these URLs work the same way from any location:
# Browse to:
https://gordie.spouterinn.org   # Cloudflare Access prompts for login → Proxmox
https://ups.spouterinn.org      # Cloudflare Access prompts for login → UPS
https://jackie2.spouterinn.org  # Cloudflare Access SSO → Synology DSM
https://pudge.spouterinn.org    # Cloudflare Access SSO → Synology DSM
https://photos.organmorgan.org  # (When Immich is deployed)

# All traffic goes through Cloudflare - no direct access
# Same experience whether you're at home or traveling
```

#### Testing LAN-Only Access (Jellyfin):
```bash
# From a device on your local network:
http://jellyfin.spouterinn.org  # Direct to VIP, no Cloudflare
# OR (if using .home domain):
http://jellyfin.home            # Direct to VIP, no Cloudflare

# This will NOT work from outside your network (by design)
```

#### Verifying Zero Trust Security:
```bash
# Try to access services directly (should fail):
curl http://10.200.10.99:8080   # Should timeout or reject (no public route)
curl https://puck-worker-01.spouterinn.org:443  # Should not resolve/route

# This confirms everything goes through Cloudflare
```

### Troubleshooting

If external access doesn't work:
```bash
# Check tunnel status in Cloudflare dashboard
# Networks → Tunnels → puck-cluster → Should show "Healthy"

# Check cloudflared logs
kubectl -n cloudflared logs deploy/cloudflared

# Check Caddy is accessible from cloudflared
kubectl -n cloudflared exec deploy/cloudflared -- curl -H "Host: gordie.spouterinn.org" http://caddy-gateway.ingress:80
```

If internal access doesn't work:
```bash
# Check kube-vip assigned the LoadBalancer IP
kubectl -n ingress get svc caddy-gateway
# EXTERNAL-IP should be 10.200.10.99

# Check Caddy is running
kubectl -n ingress get pods
kubectl -n ingress logs deploy/caddy-gateway

# Test from inside cluster
kubectl run test --rm -it --image=busybox -- wget -O- http://caddy-gateway.ingress
```

## Step 12: Create Required Secrets

Flux will be waiting for some encrypted secrets. Create them:

### PostgreSQL credentials

```bash
# Create secret file
cat > apps/work/postgres/secret.credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-pg-credentials
  namespace: work
type: kubernetes.io/basic-auth
stringData:
  username: appuser
  password: CHANGE_THIS_PASSWORD
EOF

# Encrypt with SOPS
sops -e -i apps/work/postgres/secret.credentials.yaml

# Verify it's encrypted (should see "sops:" metadata)
cat apps/work/postgres/secret.credentials.yaml

# Commit and push
git add apps/work/postgres/secret.credentials.yaml
git commit -m "Add postgres credentials"
git push
```

### Other secrets to create

Check `apps/` directories for `secret.*.template.yaml` files and create corresponding encrypted secrets:

- `apps/dmz/immich/secret.db-url.yaml`
- `apps/dmz/cloudflared/secret.tunnel-token.yaml`
- `apps/work/minio/secret.creds.yaml`
- `apps/dev/devbox/secret.ssh.yaml`
- `apps/dev/devbox/secret.tailscale.yaml`

For each:
1. Copy the template (if it exists)
2. Fill in your values
3. Encrypt: `sops -e -i path/to/secret.whatever.yaml`
4. Commit and push

## Verification Checklist

- [ ] Both nodes show "Ready" in `kubectl get nodes`
- [ ] Worker's 700GB disk mounted at `/var/mnt/data`
- [ ] Flux installed and reconciling
- [ ] Cilium pods running (CNI)
- [ ] CoreDNS pods running (DNS)
- [ ] Local-path-provisioner running (storage)
- [ ] CNPG operator running (PostgreSQL)
- [ ] Caddy ingress running
- [ ] All secrets encrypted and pushed to Git

## Understanding SANs and Adding Nodes

### When You DON'T Need to Update SANs

#### ✅ Adding Worker Nodes

Workers are **clients** that connect **to** the control plane. They don't need to be in the control plane's certificate.

```bash
# Add as many workers as you want - no control plane SAN changes needed!
# Generate new worker config
talosctl gen config puck https://puck-cp-01.spouterinn.org:6443 \
  --output-dir ./talos-configs-worker-02

# Edit the worker config
# Set hostname to puck-worker-02
# Set certSANs for puck-worker-02 (DNS, IP, Tailscale names)
# Add disks section if needed

# Apply the config
talosctl apply-config --insecure \
  --nodes puck-worker-02.spouterinn.org \
  --file ./talos-configs-worker-02/worker.yaml
```

Each worker gets its own config with its own hostname/SANs for **its own** Talos API (so you can `talosctl` into that specific worker).

### When You DO Need to Update SANs

#### ⚠️ Adding More Control Planes (HA Setup)

If you add a second/third control plane, you'll typically add a **VIP (Virtual IP)** that load balances across all control planes. This VIP needs to be in the SANs.

**Example HA setup**:
```
Control Planes:
  - puck-cp-01: 10.200.10.50
  - puck-cp-02: 10.200.10.51
  - puck-cp-03: 10.200.10.52

VIP (kube-vip): 10.200.10.99
DNS: puck-api.spouterinn.org → 10.200.10.99
```

You would then need to:

1. **Enable kube-vip** in `infra/kustomization.yaml` (currently commented out)
2. **Configure kube-vip** with the VIP address in `infra/kube-vip/daemonset.yaml`
3. **Regenerate configs** with the VIP as the endpoint:
   ```bash
   talosctl gen config puck https://10.200.10.99:6443 \
     --output-dir ./talos-configs-ha
   ```

4. **Add all SANs** to include old and new endpoints:
   ```yaml
   machine:
       certSANs:
           - puck-cp-01.spouterinn.org
           - 10.200.10.50
           - puck-api.spouterinn.org  # NEW: VIP DNS
           - 10.200.10.99            # NEW: VIP IP
           - puck-cp-01               # Tailscale short name
           - puck-cp-01.tail4bbba.ts.net
   cluster:
       apiServer:
           certSANs:
               - puck-cp-01.spouterinn.org
               - 10.200.10.50
               - puck-api.spouterinn.org  # NEW: VIP DNS
               - 10.200.10.99            # NEW: VIP IP
               - puck-cp-01               # Tailscale short name
               - puck-cp-01.tail4bbba.ts.net
   ```

5. **Apply the updated config** to all control planes
6. **Add new control plane nodes** with the updated config

#### Other Scenarios That Need SAN Updates

- **Adding a load balancer** in front of the control plane
- **Changing DNS names** (e.g., moving to a different domain)
- **Exposing via CloudFlare Tunnel** (would need the tunnel hostname)

### Your Current SANs (Already Configured)

#### Control Plane:
```yaml
# Talos API (talosctl commands)
machine:
    certSANs:
        - puck-cp-01.spouterinn.org    # Local DNS
        - 10.200.10.50                  # Local IP
        - puck-cp-01                    # Tailscale short name
        - puck-cp-01.tail4bbba.ts.net   # Tailscale full name

# Kubernetes API (kubectl commands)
cluster:
    apiServer:
        certSANs:
            - puck-cp-01.spouterinn.org    # Local DNS
            - 10.200.10.50                  # Local IP
            - puck-cp-01                    # Tailscale short name
            - puck-cp-01.tail4bbba.ts.net   # Tailscale full name
```

#### Worker:
```yaml
machine:
    certSANs:
        - puck-worker-01.spouterinn.org
        - 10.200.10.55
        - puck-worker-01
        - puck-worker-01.tail4bbba.ts.net
```

This allows you to:
- ✅ Add unlimited workers (no control plane SAN changes needed)
- ✅ Connect via local DNS or IP
- ✅ Connect via Tailscale from anywhere
- ✅ Use `talosctl` and `kubectl` from any location

## Next Steps

1. **Configure backups**: Set up off-cluster etcd backups (see `hack/backup/README.md`)
2. **Test restore**: Run a restore drill (see `hack/drills/restore-drill.md`)
3. **Add nodes to Tailscale**: Follow `docs/tailscale-mgmt.md` to expose nodes on your tailnet
4. **Configure Caddy**: Set up ingress routes for your apps
5. **Deploy applications**: Let Flux deploy Immich, PostgreSQL, MinIO, etc.

## Common Issues

### talosctl: "error constructing client: failed to determine endpoints"

This means talosctl doesn't know where to connect. Fix it:

```bash
# Set the context
talosctl config context puck

# Add endpoints
talosctl config endpoint puck-cp-01.spouterinn.org puck-worker-01.spouterinn.org

# Set default nodes
talosctl config node puck-cp-01.spouterinn.org puck-worker-01.spouterinn.org

# Verify
talosctl config info

# Try again
talosctl --nodes puck-cp-01.spouterinn.org version
```

### Node won't bootstrap
- Check time sync: `talosctl --nodes puck-cp-01.spouterinn.org time status`
- Check network: `talosctl --nodes puck-cp-01.spouterinn.org get members`
- Check etcd: `talosctl --nodes puck-cp-01.spouterinn.org service etcd status`

### Worker disk not mounting
- Verify disk exists: `talosctl --nodes puck-worker-01.spouterinn.org get disks`
- Check machine config: `talosctl --nodes puck-worker-01.spouterinn.org get machineconfig -o yaml | grep -A 5 disks`
- View logs: `talosctl --nodes puck-worker-01.spouterinn.org dmesg | grep sdb`

### Pods pending
- Check PVC status: `kubectl get pvc -A`
- Check storage class: `kubectl get sc`
- Check local-path logs: `kubectl -n kube-system logs -l app.kubernetes.io/name=local-path-provisioner`

### Flux not syncing
- Check SOPS secret: `kubectl -n flux-system get secret sops-age`
- Check Git source: `flux get sources git`
- Force sync: `flux reconcile kustomization infra --with-source`

### Certificate errors when connecting
- Verify SANs are in the config: `talosctl --nodes 10.200.10.50 get machineconfig -o yaml | grep -A 10 certSANs`
- Check the name you're using matches a SAN
- Try connecting via IP instead: `talosctl --nodes 10.200.10.50 version`

### Tailscale connection not working
- Verify node is added to tailnet: check Tailscale admin console
- Check you're using the correct Tailscale hostname
- Ensure MagicDNS is enabled in your Tailscale settings

### Cannot ping or resolve puck-cp-01.spouterinn.org
- Verify DNS is working: `nslookup puck-cp-01.spouterinn.org`
- Check DHCP reservation is active on your router
- Try using IP address instead: `talosctl --nodes 10.200.10.50 version`

## Useful talosctl Shortcuts

Add these to your shell profile (`~/.zshrc` or `~/.bashrc`) for convenience:

```bash
# Set talosctl config location
export TALOSCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/talos/config"

# Optional: Create an alias for common talosctl operations
alias tctl='talosctl'

# After setting up your cluster once, you can set default nodes:
# (Run this manually after Step 1, it modifies your config file)
# talosctl config node puck-cp-01.spouterinn.org puck-worker-01.spouterinn.org

# Then you can run commands without -n:
# talosctl dashboard
# talosctl get members
# talosctl health
```

## Quick Reference: Access Patterns

### Zero Trust Access (All Locations - via Cloudflare)
```bash
# These work the SAME from anywhere (home network or internet):
https://gordie.spouterinn.org     → Cloudflare Access → Proxmox
https://ups.spouterinn.org        → Cloudflare Access → UPS
https://jackie2.spouterinn.org    → Cloudflare Access + OAuth → Synology DSM
https://pudge.spouterinn.org      → Cloudflare Access + OAuth → Synology DSM
https://photos.organmorgan.org    → Cloudflare Access → Immich (when deployed)

Flow: User → Cloudflare Edge (auth) → Tunnel → Caddy → Backend Service
```

### LAN-Only Access (Local Network Only)
```bash
# Only accessible from your local network:
http://jellyfin.spouterinn.org   → Direct to 10.200.10.99 → Jellyfin
# OR:
http://jellyfin.home             → Direct to 10.200.10.99 → Jellyfin

Flow: User on LAN → Internal DNS → kube-vip VIP → Caddy → Jellyfin
NOT accessible from internet (Cloudflare ToS violation for streaming)
```

### Service Authentication Summary
| Service | Access | Auth Method | SSO | Notes |
|---------|--------|-------------|-----|-------|
| Proxmox (gordie) | Cloudflare | OAuth/OIDC | ✅ | Infrastructure mgmt with SSO |
| UPS | Cloudflare | Email only | No | Front-door protection |
| Synology (jackie2) | Cloudflare | OAuth/OIDC | ✅ | NAS with SSO |
| Synology (pudge) | Cloudflare | OAuth/OIDC | ✅ | NAS with SSO |
| Immich (photos) | Cloudflare | OAuth/OIDC | ✅ | Photo library with SSO |
| Jellyfin | LAN-only | None (CF) | No | Streaming - CF ToS |

### Key IP Addresses
- **10.200.10.40** - Gordie (Proxmox VE)
- **10.200.10.41** - UPS Management
- **10.200.10.44** - Jackie2 (Synology NAS)
- **10.200.10.45** - Pudge (Synology NAS)
- **10.200.10.50** - puck-cp-01 (control plane)
- **10.200.10.55** - puck-worker-01 (worker node)
- **10.200.10.99** - kube-vip VIP (LoadBalancer - used for Jellyfin only)

## References

- [Talos Documentation](https://www.talos.dev/latest/)
- [Talos Machine Config Reference](https://www.talos.dev/latest/reference/configuration/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [SOPS Documentation](https://github.com/getsops/sops)
- [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
- [kube-vip Documentation](https://kube-vip.io/)
- Project docs: `docs/DISASTER-RECOVERY.md`, `docs/ADDING-WORKLOADS.md`, `docs/tailscale-mgmt.md`
