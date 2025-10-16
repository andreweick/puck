Add every IP/DNS you will use for kubectl (LAN/WG, Tailscale IP/DNS, optional VIP).

1) Edit your generated control-plane config:
   _out/controlplane.yaml → under `cluster.apiServer` add `certSANs`.
2) Apply and refresh kubeconfig:
   talosctl --nodes <CP_IP> --insecure apply-config --file _out/controlplane.yaml
   talosctl --talosconfig _out/talosconfig kubeconfig . --force
