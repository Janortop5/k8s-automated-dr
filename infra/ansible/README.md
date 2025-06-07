# ansible-playbook-to-install-docker
*Fun project to develop, learn and build.

## How to use k8s_lstm_pipeline role
```bash
pip install ansible kubernetes

cd infra/ansible

ansible-playbook kubeadm.yml -i hosts
```
## Commands Quick-Start

1. **Verify PVC & Pods**
  ```bash
   kubectl -n monitoring get pvc
   kubectl -n monitoring get pods -l release=prometheus
  ```

  **Access Prometheus UI**

Locally (if you have kubectl configured):
```bash
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
# → browse http://localhost:9090
```

**Via SSH tunnel (if you’re SSH’d into a node):**

```bash
ssh -N -L 9090:127.0.0.1:9090 ubuntu@<node-ip> -i k8s-cluster.pem
# → browse http://localhost:9090
```

**Check Targets & Sample Queries**

Targets: In Prometheus UI → Status → Targets

**Sample PromQL:**

```promql
rate(node_cpu_seconds_total{mode!="idle"}[5m])
container_memory_usage_bytes{container!=""}
```

**Cleanup**
```bash
helm uninstall prometheus --namespace monitoring
kubectl -n monitoring delete pvc prometheus-data-*
```
