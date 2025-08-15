# k8s-automated-dr
## Checklist Mapping
#### Done
- Prepare and Clean **Metrics**, Train and **Apply {LSTM} Model**
- Make all provisioning and server installations in **IaC**
- **Automate** Jenkins Setup [ Credentials, Cloud, Plugins, Jenkinsfile ]
- Establish **Security**
#### Todo
- Create dashboards
- Test **DR**
- Deployment
- Maintenance


## 1. High-Level System Concept
An automated end‑to‑end platform that:
- Provisions AWS infrastructure (network, compute, access, DNS) via Terraform (primary + standby environments).
- Bootstraps a self-managed Kubernetes cluster on EC2 via Ansible (kubeadm pattern).
- Installs CI/CD (Jenkins) and wires it into the cluster with Groovy initialization scripts.
- Deploys data + metrics collectors, an LSTM model service, observability (Prometheus stack), backup/restore (Velero), chaos/testing, and an event trigger (Node.js).
- Implements disaster recovery via Velero + a “standby” Terraform stack + reproducible Ansible runs.
- Integrates secrets, OIDC, and templated deployment artifacts for consistent promotion.

## 2. Layered Architecture
1. Foundation (Terraform):
   - Remote state + backend separation.
   - VPC, subnets, security groups, ALB, EC2 (control plane & workers, Jenkins host).
   - DNS (Name.com module) for external access (likely Jenkins + app endpoints).
   - OIDC module for identity integration (Jenkins or cluster access).
   - Secret vault module(s) for external secret stores.
   - Separate “standby_terraform” for DR region or cold/warm failover.

2. Configuration (Ansible):
   - Inventory + host_vars for role specialization (Jenkins node, trigger node, Velero).
   - Task files split by concern: container runtime (`setup_containerd.yml`), kube toolchain, kubeadm bootstrap, join workers, Helm installation, Jenkins setup, plugin provisioning, Velero install, Vault integration, metrics collector update, recovery bootstrap.
   - Group vars (`secrets.yml`) encrypted (likely Ansible Vault) to manage credentials.
   - Jinja2 templates (e.g., `metrics_collector_deployment.yaml.j2`, `nodejs-trigger.env.j2`) enabling environment-specific artifacts emitted during runs.

3. Orchestration Hooks (Groovy + Node.js):
   - Groovy startup scripts (`add-kubeconfig.groovy`, `configure-k8s-cloud.groovy`, `create-credentials.groovy`, `oidc-init.groovy`) embed cluster credentials, add cloud provider, create Jenkins credentials, configure OIDC integration.
   - Node.js trigger service (`trigger/index.js`, `package.json`) acts as an inbound event bridge (e.g., webhook → Jenkins job trigger or model inference pipeline).

4. Kubernetes Workloads (YAML):
   - Metrics collector (`files/k8s-collector/metric_collector_deployment.yml` & templated variant) gathers cluster/app metrics.
   - Data sync (`k8s-metrics-data/data-sync.yml`) loads or transfers data into storage for ML or backup.
   - LSTM model deployment (`k8s-model/lstm_model_deployment.yml`) exposes predictive service (e.g., anomaly or recovery risk scoring).
   - Observability (`k8s-observability/values-prometheus.yaml`) extends Prometheus stack (scrape configs, retention, alerting).
   - Chaos testing placeholder directory for resilience experiments (possibly injecting faults).
   - Backup (`velero.yml`) installs Velero + schedules + storage provider configuration.
   - Audit policy (`k8s-metrics-data/audit-policy.yaml`) adds security + compliance signal stream.

5. Disaster Recovery:
   - Velero snapshots of etcd (via API) & persistent volumes (object storage).
   - Standby Terraform infra enables rapid redeploy + restore sequence.
   - Ansible `setup_recovery.yml` + `setup_vault.yml` orchestrate secret rehydration and cluster state rebuild.
   - LSTM model + metrics help drive proactive readiness or detect abnormalities prompting DR actions.

## 3. Technical Goals
- Deterministic environment recreation (infra + platform + workloads).
- Automated CI/CD bootstrap with minimal manual credential injection.
- Observability-first: metrics, logging (implied), auditing for governance.
- Predictive resilience via ML (LSTM) leveraging historical performance metrics.
- Disaster recovery readiness (infrastructure dual definition + Velero + recovery playbooks).
- Event-driven operations (Node.js trigger bridging external systems to Jenkins).
- Secure secret handling and identity federation (OIDC + Vault/secret modules).

## 4. Information Flow
1. Provisioning:
   - Terraform applies → creates VPC, subnets, security groups, EC2, ALB, DNS entries.
   - Outputs: IPs, DNS names, instance attributes → fed to Ansible (either via dynamic inventory generation or variable outputs passed manually/CI).

2. Cluster Bootstrap:
   - Ansible runs: container runtime → kubeadm init → control plane config → join workers → install CNI (implied in `setup_kubetools.yml`) → Helm installed.

3. CI/CD Enablement:
   - Jenkins installed (Ansible `install_jenkins.yml`).
   - Plugins & custom Groovy seeds configure:
     - Credentials (cloud, kubeconfig, registry, OIDC).
     - Kubernetes cloud integration for dynamic agents.
     - Adds cluster kubeconfig (Groovy + ansible-provided file).
   - Jenkins obtains ability to run pipeline stages inside cluster or on ephemeral agents.

4. Application & Services Deployment:
   - Ansible templates dynamic manifests (e.g., metrics collector).
   - Jenkins or Ansible applies them via kubectl/Helm.
   - Node.js trigger service waits for external events (e.g., model retrain, metrics anomaly) → triggers Jenkins job → pipeline may redeploy model or rotate configurations.

5. Observability Loop:
   - Prometheus scrapes workloads & system metrics.
   - Metrics collector possibly normalizes or exports (to TSDB or intermediate store).
   - LSTM service ingests metric time series (batch or streaming) to produce anomaly/failure likelihood signals.
   - Alerts (Prometheus Alertmanager) route to Jenkins or trigger service → orchestrated remediation or DR readiness check.

6. Backup & DR Path:
   - Velero schedules periodic backups (cluster objects + PV snapshots).
   - On incident: standby Terraform environment applied → Ansible replays bootstrap (minus initial cluster data if restoring).
   - Velero restore phase → rehydrate Kubernetes objects → redeploy model + metrics pipeline → Node.js trigger reattached.
   - Secrets restored from vault module + Ansible `setup_vault.yml`.

## 5. Technical Framework & Tooling Stack
- Infrastructure as Code: Terraform modules (composition + reusability).
- Configuration Management: Ansible (idempotent, role/task structured).
- CI/CD: Jenkins (Groovy init DSL, plugin automation).
- Container Orchestration: Kubernetes (self-managed kubeadm cluster).
- Observability: Prometheus (values override), auditing policy, metrics collector.
- ML Serving: LSTM model container (likely Python with dependencies defined elsewhere).
- Disaster Recovery: Velero + secondary Terraform stack + recovery playbooks.
- Security & Identity: OIDC integration, secrets vaults, controlled kubeconfig injection.
- Automation Patterns: Template-driven manifests, event-driven trigger microservice.

## 6. Design Principles
- Separation of Concerns: Terraform (infra), Ansible (node & cluster config), Jenkins (delivery), YAML manifests (runtime workloads).
- Layered Idempotence: Each stage can be re-applied without destructive drift (except controlled updates).
- Declarative Edge: Kubernetes manifests & Velero resources declare desired resilient state.
- Extensibility: Modular directory structure (adding new services via new module/play + template).
- DR Parity: Standby stack mirrors primary for RPO/RTO optimization.
- Security-by-Initialization: Groovy bootstraps credentials early to avoid manual console steps.
- Predictive Ops: Integration of ML (LSTM) into operational feedback loop.

## 7. Component Breakdown
- Terraform Root (`main.tf`, `locals.tf`, `providers.tf`, `variables.tf`, modules/*): orchestrates region/provider config, passes outputs to modules.
- Module: `ec2/` (cluster & service hosts, networking, ALB).
- Module: `aws_openid/` (assumed OIDC provider + trust relationships for roles).
- Module: `name_dot_com/` (DNS zone + record management).
- Module: `secret_vaults/` (abstract secret store integration).
- Module: `ansible_setup` / `ansible_run` (provisions context or triggers remote execution wrapper).
- Ansible Tasks: granular operational scripts (Docker/containerd, kube tools, join logic, plugins, velero, vault, updates).
- Templates: environment variable injection & deployment substitution logic.
- Groovy Scripts: Jenkins dynamic configuration at startup (credentials, cloud, OIDC).
- Node.js Trigger: Event ingress + pipeline invocation.
- Observability Config: `values-prometheus.yaml` influences retention, scrape intervals, exporters.
- Backup Config: `velero.yml` defines provider (e.g., S3 bucket), schedules, restore hooks.
- ML & Data Manifests: deployments for LSTM model + metric ingestion + data sync pipeline.
- Audit Policy: governance & security telemetry.

## 8. Disaster Recovery Mechanism
- Data Layer: Velero object + volume snapshots.
- Infra Layer: “standby_terraform” replicates network & compute skeleton.
- Control Layer: Ansible `setup_recovery.yml` reconstructs cluster baseline, then Velero restore.
- Application Layer: Jenkins redeploys pipelines; metrics + model redeployed; triggers re-register.
- Validation Loop: Observability & LSTM anomaly detection confirm restored service health.

## 9. Unique Mechanisms / Cross‑Cutting Patterns
- Dual environment Terraform (primary + standby) embedded in same repo for synchronous evolution.
- Unified bootstrap chain: Terraform outputs → Ansible tasks → Jenkins Groovy injection → Kubernetes dynamic agents & workloads.
- ML‑in‑the‑loop for reliability (LSTM not just app feature, but platform feedback).
- Template bridging (Jinja2) to keep Kubernetes specs environment-agnostic until late binding.
- Event-driven CI triggers (Node.js) decoupling external stimuli from Jenkins internal APIs.
- DR-as-Code: Recovery playbooks + backup manifests versioned alongside provisioning.
- Security instrumentation at bootstrap (OIDC & audit policy) rather than post-hoc hardening.

## 10. End-to-End Technical Walkthrough (Condensed Sequence)
1. Run Terraform (primary): builds infra + outputs addresses.
2. Run Ansible: sets up runtime (containerd, kubeadm init, joins, Helm, Jenkins, Velero).
3. Jenkins starts; Groovy scripts add kube cloud + credentials + OIDC roles.
4. Deploy Prometheus stack, metrics collector, data sync, model service, trigger service.
5. Metrics flow into Prometheus + collector; model consumes time series; trigger listens for events.
6. Velero runs scheduled backups; standby environment kept in parity code-wise.
7. On anomaly: LSTM flags issue → Jenkins pipeline can initiate remedial tasks (redeploy, scale, or DR simulation).
8. On failure: apply standby Terraform, run recovery Ansible, restore via Velero, resume workloads, validate via metrics + model.

## 11. Technical Goals Coverage
- Automation: Terraform + Ansible + Groovy + triggers.
- Observability: Prometheus + audit + custom collector.
- Resilience: Chaos testing scaffold + ML anomaly detection + Velero + standby infra.
- Security: OIDC, secrets vault integration, controlled kubeconfig provisioning.
- Reproducibility: Idempotent layered code and versioned manifests.
- Extensibility: Modular decomposition (add new module/play/service without refactor).

## 12. Potential Enhancements (Optional)
- Add policy-as-code (OPA/Gatekeeper) for continuous compliance.
- Add automated drift detection between primary and standby Terraform states.
- Introduce structured event bus (e.g., SNS/SQS) feeding Node.js trigger for reliability.
- Integrate canary or progressive delivery (Argo Rollouts) for model updates.
- Central secret rotation pipeline integrated into Jenkins.

## 13. Summary
The infra directory implements a multi-layered IaC + configuration + runtime deployment system focused on resilient Kubernetes operations, embedding ML-driven anomaly detection, automated CI/CD provisioning, event-triggered workflows, and disaster recovery readiness—tying Terraform (infra), Ansible (config), Jenkins (delivery), Kubernetes (runtime), Velero (DR), Prometheus (observability), and an LSTM model (predictive resilience) into a cohesive, reproducible architecture.
