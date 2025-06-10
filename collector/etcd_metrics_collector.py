# etcd metrics currently not used in training, but can be used for future analysis
import requests
import pandas as pd
import time
import os

def collect_prometheus_metrics(query, prometheus_url="http://prometheus-kube-prometheus-prometheus.monitoring.svc.local:9090"):
    response = requests.get(
        f"{prometheus_url}/api/v1/query",
        params={"query": query}
    )
    results = response.json()['data']['result']
    return results

def save_metrics_to_csv(metrics, filename):
    # Convert metrics to DataFrame and save
    df = pd.DataFrame(metrics)
    os.makedirs("data", exist_ok=True)
    df.to_csv(f"data/{filename}", index=False)

# Main collection loop
if __name__ == "__main__":
    while True:
        # CPU usage per pod
        cpu_metrics = collect_prometheus_metrics("sum(rate(container_cpu_usage_seconds_total{container!=''}[5m])) by (pod)")
        
        # Memory usage per pod
        mem_metrics = collect_prometheus_metrics("sum(container_memory_usage_bytes{container!=''}) by (pod)")
        
        # Pod restart count
        restart_metrics = collect_prometheus_metrics("kube_pod_container_status_restarts_total")
        
        # Save with timestamp
        timestamp = int(time.time())
        save_metrics_to_csv(cpu_metrics, f"cpu_metrics_{timestamp}.csv")
        save_metrics_to_csv(mem_metrics, f"mem_metrics_{timestamp}.csv")
        save_metrics_to_csv(restart_metrics, f"restart_metrics_{timestamp}.csv")
        
        # Wait before next collection
        time.sleep(300)  # 5 minutes