# Adding a new workload

Two paths:
1) **Helm chart** (Flux Helm Controller) — add a HelmRepository and a pinned HelmRelease
2) **From Docker Compose** — convert to Deployment/Service/PVC/ConfigMap/Secret + Caddy host

## 1) Helm chart example (Bitnami Redis)
```yaml
# apps/cache/redis/repo.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata: { name: bitnami, namespace: cache }
spec: { interval: 1h, url: https://charts.bitnami.com/bitnami }
---
# apps/cache/redis/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata: { name: redis, namespace: cache }
spec:
  interval: 10m
  chart:
    spec:
      chart: redis
      sourceRef: { kind: HelmRepository, name: bitnami, namespace: cache }
      version: "18.6.0"   # pinned
  values:
    architecture: standalone
    auth: { enabled: true, password: "CHANGE_ME" }
    master:
      persistence: { storageClass: local-path, size: 8Gi }
```

## 2) From Docker Compose (outline)
- Config → ConfigMap; secrets → Secret (encrypt with SOPS)
- Deployment/StatefulSet with image, env, ports, volumeMounts
- PVC: `local-path` for RWO on NVMe, `synology-nfs` for RWX
- Service (ClusterIP)
- NetworkPolicy (default-deny + specific allows)
- Caddy host route in `infra/ingress/caddyfile-gateway/caddy-configmap.yaml`
- (Optional) Flux ImageAutomation for image auto-bumps

## Webhook for instant reconciles (optional)
Create a Flux **Receiver** and GitHub webhook so pushes reconcile immediately; otherwise Flux polls every minute.
