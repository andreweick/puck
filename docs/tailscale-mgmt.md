# Tailscale Management Path (optional)

Expose only:
- Kubernetes API **:6443** (for `kubectl`)
- Talos API **:50000** (for `talosctl`)

## 1) Add SANs for TLS
Edit your **controlplane machine config**:
```yaml
cluster:
  apiServer:
    certSANs:
      - 10.200.10.30            # LAN/WG
      - puck-api.ts.net         # Tailscale MagicDNS
      - 100.x.y.z               # Tailscale IP (optional)
      # - 192.168.1.100         # kube-vip (optional)
      # - k8s.home.arpa         # DNS (optional)
```
Apply & refresh kubeconfig:
```bash
talosctl --nodes <CP_IP> --insecure apply-config --file controlplane.yaml
talosctl --talosconfig _out/talosconfig kubeconfig . --force
```

## 2) Deploy the mgmt DaemonSet (control-plane only)
See `infra/tailscale-apiserver/`. It runs with `hostNetwork` and proxies:
```
tailscale serve tcp 6443 127.0.0.1:6443
tailscale serve tcp 50000 127.0.0.1:50000
```

## 3) ACLs (Tailscale)
Allow only your device(s) to reach those ports:
```json
{ "acls": [
  { "action": "accept", "src": ["you@tailnet"], "dst": ["puck-api:6443","puck-api:50000"] }
]}
```

## 4) Use it
```bash
kubectl --server https://puck-api.ts.net:6443 get nodes
talosctl --nodes puck-api.ts.net etcd status
```
