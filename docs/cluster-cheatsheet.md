# Puck Cluster Cheatsheet

## Cluster Information

**Control Plane Node:**
- Hostname: `puck-cp-01.spouterinn.org`
- IP: `10.200.10.50`

**Worker Nodes:**
- Hostname: `puck-worker-01.spouterinn.org`
- IP: `10.200.10.55`

---

## kubectl Commands

### Node Management

```bash
# List all nodes with details
kubectl get nodes --output wide

# List all nodes across all namespaces
kubectl get nodes --all-namespaces

# Describe a specific node
kubectl describe node puck-cp-01
kubectl describe node puck-worker-01

# Get node resource usage
kubectl top nodes
```

### Pod Management

```bash
# List all pods in current namespace
kubectl get pods

# List all pods with more details
kubectl get pods --output wide

# List all pods in all namespaces
kubectl get pods --all-namespaces

# List pods in a specific namespace
kubectl get pods --namespace flux-system

# Describe a specific pod
kubectl get pods --namespace <namespace>
kubectl describe pod <pod-name> --namespace <namespace>

# Get pod logs
kubectl logs <pod-name> --namespace <namespace>

# Follow pod logs in real-time
kubectl logs <pod-name> --namespace <namespace> --follow

# Get logs from previous container instance
kubectl logs <pod-name> --namespace <namespace> --previous
```

### Deployment Management

```bash
# List all deployments
kubectl get deployments --all-namespaces

# List deployments in specific namespace
kubectl get deployments --namespace <namespace>

# Describe a deployment
kubectl describe deployment <deployment-name> --namespace <namespace>

# Scale a deployment
kubectl scale deployment <deployment-name> --namespace <namespace> --replicas 3

# Restart a deployment
kubectl rollout restart deployment <deployment-name> --namespace <namespace>

# Check rollout status
kubectl rollout status deployment <deployment-name> --namespace <namespace>
```

### Service Management

```bash
# List all services
kubectl get services --all-namespaces

# List services in specific namespace
kubectl get services --namespace <namespace>

# Describe a service
kubectl describe service <service-name> --namespace <namespace>
```

### Resource Information

```bash
# List all resource types
kubectl api-resources

# Get events in a namespace
kubectl get events --namespace <namespace>

# Get events sorted by timestamp
kubectl get events --namespace <namespace> --sort-by='.lastTimestamp'
```

---

## talosctl Commands

### Node Operations

```bash
# Reboot a node (graceful, automatic restart)
talosctl reboot --nodes puck-worker-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org
talosctl reboot --nodes 10.200.10.55 --endpoints 10.200.10.50

# Reboot control plane node
talosctl reboot --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org
talosctl reboot --nodes 10.200.10.50 --endpoints 10.200.10.50

# Shutdown a node
talosctl shutdown --nodes puck-worker-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# View node dashboard
talosctl dashboard --nodes puck-cp-01.spouterinn.org,puck-worker-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# Get node version
talosctl version --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org
```

### Resource Management

```bash
# List all resource types
talosctl get rd --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# Get cluster members
talosctl get members --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# Get node config
talosctl get machineconfig --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# Get resources in YAML format
talosctl get members --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org --output yaml

# Get resources in JSON format
talosctl get members --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org --output json

# Watch resource changes
talosctl get members --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org --watch
```

### Logs and Debugging

```bash
# View service logs
talosctl logs --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org <service-name>

# Follow logs in real-time
talosctl logs --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org <service-name> --follow

# View kernel logs (dmesg)
talosctl dmesg --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# Follow kernel logs
talosctl dmesg --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org --follow
```

### Configuration

```bash
# Set default endpoints in talosconfig
talosctl config endpoint puck-cp-01.spouterinn.org

# View current config
talosctl config info

# Validate config
talosctl validate --config <config-file>
```

---

## Flux CD Commands

### Status and Information

```bash
# Check Flux installation
flux check

# Check prerequisites before install
flux check --pre

# Get all Flux resources
flux get all --all-namespaces

# Get GitRepository sources
flux get sources git --all-namespaces

# Get Kustomizations
flux get kustomizations --all-namespaces

# Get HelmReleases
flux get helmreleases --all-namespaces

# View Flux logs
flux logs --all-namespaces

# Follow Flux logs in real-time
flux logs --all-namespaces --follow
```

### Reconciliation

```bash
# Trigger reconciliation of flux-system
flux reconcile source git flux-system --namespace flux-system

# Reconcile a specific GitRepository
flux reconcile source git <repo-name> --namespace <namespace>

# Reconcile a Kustomization
flux reconcile kustomization <kustomization-name> --namespace <namespace>

# Reconcile a Kustomization with its source
flux reconcile kustomization <kustomization-name> --namespace <namespace> --with-source

# Reconcile a HelmRelease
flux reconcile helmrelease <release-name> --namespace <namespace>
```

### Suspend and Resume

```bash
# Suspend a Kustomization
flux suspend kustomization <kustomization-name> --namespace <namespace>

# Resume a Kustomization
flux resume kustomization <kustomization-name> --namespace <namespace>

# Suspend a HelmRelease
flux suspend helmrelease <release-name> --namespace <namespace>

# Resume a HelmRelease
flux resume helmrelease <release-name> --namespace <namespace>
```

### Export and Debugging

```bash
# Export all GitRepository sources
flux export source git --all-namespaces > git-sources.yaml

# Export all Kustomizations
flux export kustomization --all-namespaces > kustomizations.yaml

# View events for Flux resources
flux events --all-namespaces

# View events for a specific resource
flux events --for Kustomization/<kustomization-name> --namespace <namespace>

# Trace a resource through the pipeline
flux trace <resource-name> --namespace <namespace>

# Show stats of reconciliations
flux stats
```

---

## Common Workflows

### Rebooting the Cluster

Reboot nodes one at a time, starting with workers:

```bash
# 1. Reboot worker node
talosctl reboot --nodes puck-worker-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# 2. Wait for worker to come back
kubectl get nodes

# 3. Reboot control plane
talosctl reboot --nodes puck-cp-01.spouterinn.org --endpoints puck-cp-01.spouterinn.org

# 4. Verify cluster is healthy
kubectl get nodes
flux check
```

### Debugging a Failed Deployment

```bash
# 1. Check pod status
kubectl get pods --namespace <namespace>

# 2. Describe the pod
kubectl describe pod <pod-name> --namespace <namespace>

# 3. Check pod logs
kubectl logs <pod-name> --namespace <namespace>

# 4. Check Flux reconciliation
flux get kustomizations --all-namespaces
flux events --all-namespaces

# 5. Force reconcile if needed
flux reconcile kustomization <kustomization-name> --namespace <namespace> --with-source
```

### Forcing Flux to Pull Latest Changes

```bash
# Reconcile the git source and apply changes
flux reconcile source git flux-system --namespace flux-system
flux reconcile kustomization flux-system --namespace flux-system --with-source
```
