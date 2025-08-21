# PRESENTATION
### Executive Overview Board → Metrics Mapping

| Panel | Metric(s) | Source |
|-------|-----------|--------|
| **System Health Summary** | `kube_node_status_condition{condition="Ready"}`, `kube_pod_status_phase` | kube‑state‑metrics |
| **Prediction Risk Gauge** | `lstm_prediction_risk_score` | Custom exporter from `k8s-model/lstm_model_deployment.yml` |
| **Recent DR Actions Timeline** | `dr_event_trigger_total{stage="node_drain"}`, `{stage="pod_restart"}`, `{stage="rollback"}`, `{stage="restore"}` | Node.js trigger → Prometheus pushgateway |
| **SLA/SLO Compliance** | `probe_success` (if blackbox exporter), `uptime_percentage` (recording rule) | Prometheus |
| **Backup Status** | `velero_backup_total`, `velero_backup_success_total`, `velero_backup_last_success_timestamp` | Velero metrics endpoint |

### Prediction & Prevention Board → Metrics Mapping

| Panel | Metric(s) | Source |
|-------|-----------|--------|
| **Risk Score Time Series** | `lstm_prediction_risk_score` (time series) | LSTM model service |
| **Prediction Accuracy** | `lstm_model_f1_score`, `lstm_model_precision`, `lstm_model_recall` | LSTM model service (exported via Python Prometheus client) |
| **Trigger Correlation View** | Overlay `lstm_prediction_risk_score` with `dr_event_trigger_total` | LSTM + Node.js trigger |
| **Confidence Interval Bands** | `lstm_prediction_confidence_lower`, `lstm_prediction_confidence_upper` | LSTM model service |

### Recovery Effectiveness Board → Metrics Mapping

| Panel | Metric(s) | Source |
|-------|-----------|--------|
| **RTO per Stage** | `dr_stage_rto_seconds{stage="..."}` | Calculated in Jenkins pipeline, pushed to Prometheus |
| **RPO Trend** | `time() - velero_backup_last_success_timestamp` | Velero metrics |
| **Automation Success Rate** | `dr_event_trigger_total` vs `dr_event_success_total` | Node.js trigger / Jenkins |
| **Velero Restore Metrics** | `velero_restore_total`, `velero_restore_success_total`, `velero_restore_duration_seconds` | Velero metrics endpoint |

### Technical Deep‑Dive Board → Metrics Mapping

| Panel | Metric(s) | Source |
|-------|-----------|--------|
| **Node CPU/Memory/Disk/Network** | `node_cpu_usage_seconds_total`, `node_memory_working_set_bytes`, `node_disk_io_time_seconds_total`, `node_network_transmit_bytes_total` | node‑exporter / cAdvisor |
| **Pod Restart Counts & Error States** | `kube_pod_container_status_restarts_total`, `kube_pod_status_phase{phase="Failed"}` | kube‑state‑metrics |
| **Velero Backup/Restore Logs Summary** | `velero_backup_total`, `velero_restore_total` | Velero |
| **K8s Event Counts** | `kube_event_count` (filtered by reason: Drain, Rollback, Restore) | kube‑state‑metrics / event‑exporter |

### Implementation Notes
- **Custom LSTM metrics**: In your repo, the `metrics-collector/alert_manager.py` and `k8s-model/lstm_model_deployment.yml` can expose these via `prometheus_client` in Python.
- **DR stage metrics**: The Node.js trigger service can increment counters (`dr_event_trigger_total`, `dr_event_success_total`) with `stage` as a label.
- **RTO/RPO**: RTO is a recording rule measuring `time(recovery_end) - time(trigger)`. RPO is `now() - last_backup_timestamp`.
- **Annotations in Grafana**: Use the Prometheus alert firing time or `dr_event_trigger_total` increments to auto‑annotate dashboards.

### Pipeline / Job Execution Dashboards
**Purpose:** Show each run of your automation (e.g., Jenkins DR pipeline) with status, duration, and stage breakdown.

**Typical Panels:**
- **Run history table**: Job name, start time, end time, status (success/fail), duration.
- **Stage Gantt chart**: Visual timeline of each stage (node drain → pod restart → rollback → Velero restore).
- **Failure trend**: Count of failed runs over time.
- **Trigger source**: Manual vs automated (e.g., LSTM trigger, chaos test).

**Metrics in your stack:**
- `dr_event_trigger_total{stage="..."}` — increments when a stage starts.
- `dr_event_success_total{stage="..."}` — increments when a stage completes successfully.
- `dr_stage_duration_seconds{stage="..."}` — duration per stage.
- Jenkins build metrics (via Prometheus plugin): `jenkins_job_last_build_result`, `jenkins_job_last_build_duration_seconds`.

### Test / Simulation Execution Dashboards
**Purpose:** For chaos tests or DR drills, show what was executed, when, and the outcome.

**Typical Panels:**
- **Scenario list**: Name, start/end, result.
- **Pass/fail rate**: Pie or bar chart.
- **Execution timeline**: Overlay of test start/end markers on cluster metrics.
- **Defect or anomaly log**: Count and severity of issues found.

**Metrics in your stack:**
- Chaos Mesh events (if integrated): `chaos_experiment_duration_seconds`, `chaos_experiment_failures_total`.
- LSTM prediction spikes: `lstm_prediction_risk_score` during test window.
- Recovery metrics: `dr_stage_rto_seconds`, `velero_restore_success_total`.

### Backup/Restore Execution Dashboards
**Purpose:** Show Velero jobs actually running and completing.

**Typical Panels:**
- **Backup job list**: Name, start/end, size, status.
- **Restore job list**: Same as above, filtered for restores.
- **Execution duration trend**: How long backups/restores take over time.
- **Success rate**: % of jobs completed without error.

**Metrics in your stack:**
- `velero_backup_total`, `velero_backup_success_total`, `velero_backup_duration_seconds`.
- `velero_restore_total`, `velero_restore_success_total`, `velero_restore_duration_seconds`.

### Live Execution Timeline Dashboards
**Purpose:** Show “right now” what’s running and where it is in the process.

**Typical Panels:**
- **Now running**: Current stage, elapsed time, responsible node/pod.
- **Event stream**: Real‑time log of stage start/stop events.
- **Resource overlay**: CPU/memory/network graphs with execution markers.

**Metrics in your stack:**
- Event exporter: `kube_event_count` filtered by DR action reasons.
- Node/pod metrics from kube‑state‑metrics and cAdvisor.
- Grafana annotations from `dr_event_trigger_total` timestamps.

# SLIDES

### 1. Title & Abstract
- Project title, your name, institution, date.
- A concise problem statement and one‑paragraph summary of your solution.
- Keywords: Kubernetes, Disaster Recovery, LSTM, Velero, IaC.

### 2. Problem Definition
- **Current gap**: complexity of automated DR in containerised environments.
- Why prediction‑driven DR is valuable (RTO/RPO optimisation, less downtime).
- Academic framing: state this as a research question/hypothesis.

### 3. Literature & Background
- Existing DR strategies in Kubernetes (manual vs automated).
- Short intro to LSTM for time‑series anomaly prediction.
- Velero overview for K8s backup/restore.
- Gaps your approach addresses.

### 4. System Overview
- High‑level architecture diagram: Terraform → Ansible → Jenkins → K8s cluster → Prometheus → LSTM → Node.js trigger → Velero restore.
- Show “data flow” and “control flow” separately.

### 5. Methodology
Break this into sub‑slides:
- **Infrastructure layer**: Terraform modules, standby_terraform concept.
- **Configuration layer**: Ansible roles/playbooks.
- **ML layer**: dataset, preprocessing, LSTM architecture (input features, sequence length, layers, loss function).
- **Trigger & Orchestration**: Node.js service, Jenkins pipeline stages.
- **DR Actions**: Node drain, pod restart, deployment rollback, Velero restore.

### 6. Implementation Details
- Repo structure snapshot (only relevant directories/files).
- Deployment pipeline from zero → running cluster.
- Security controls: Vault, OIDC, secrets handling.
- Chaos testing setup for evaluation.

### 7. Experimental Setup
- Cluster size, AWS instance types, workloads used for testing.
- Data characteristics (metrics collected, timespan, volume).
- Simulation parameters (fault types: CPU saturation, crash loops).

### 8. Metrics & Evaluation Criteria
- **Prediction performance**: F1 score, precision, recall.
- **DR performance**: RTO, RPO, MTTR.
- **System performance**: CPU/memory overhead, automation success rate.
- **Backup/restore**: success %, average duration.

### 9. Results — Visualised
This is where your Grafana exports shine:
- LSTM prediction vs actual incidents (time‑series with annotations).
- DR execution timeline (stage start → completion).
- Before/after recovery cluster health.
- Backup/restore trend charts.

### 10. Discussion
- Interpret results: where automation excelled, where it struggled.
- Trade‑offs between proactive vs reactive DR.
- Scalability and generalisability of your approach.

### 11. Limitations & Future Work
- Model drift and retraining frequency.
- Broader fault coverage (network partitions, storage failures).
- Multi‑cloud portability.
- Integration with policy‑driven engines (OPA, Kyverno).

### 12. Conclusion
- Restate problem, approach, and key findings.
- Summarise contributions to both academia and practice.

### 13. References
- Research papers, Kubernetes docs, Velero docs, ML sources.

### 14. Appendix (Optional)
- Additional metrics.
- Detailed PromQL queries.
- Extra architecture diagrams.

**Tips for defence day:**
- Use **animated architecture diagrams** to step through Terraform → Ansible → ML → DR.
- Keep graphs **annotated** (mark “Prediction trigger”, “Node drain start”, “Restore complete” on timelines).
- For each technical claim, link it back to your thesis objectives.
