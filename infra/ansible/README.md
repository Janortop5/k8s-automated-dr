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

2. **Access Prometheus UI**

  Locally (if you have kubectl configured):
  ```bash
  kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
  # → browse http://localhost:9090
  ```

3. **Via SSH tunnel (if you’re SSH’d into a node):**
  First ssh into the node and run the port-foward command in step 2.
  ```bash
  ssh -N -L 9090:127.0.0.1:9090 ubuntu@<node-ip> -i k8s-cluster.pem
  # → browse http://localhost:9090
  ```

4. **Check Targets & Sample Queries**

  Targets: In Prometheus UI → Status → Targets

5. **Sample PromQL:**

  ```promql
  rate(node_cpu_seconds_total{mode!="idle"}[5m])
  ```

  ```promql
  container_memory_usage_bytes{container!=""}
  ```


### Data Syncing Commands

## Setup Secrets

```bash
kubectl create secret generic rclone-secret -n monitoring \
  --from-literal=rclone.conf="[s3]
type = s3
provider = AWS
access_key_id = <secret_id>
secret_access_key = <secret_key>
region = <region-name>"
```

## Install chaos mesh
```bash
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-testing --create-namespace
```