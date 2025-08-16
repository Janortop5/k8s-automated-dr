# k8s-automated-dr
## 1. High-Level System Concept
An automated end‑to‑end platform that:
1. Provisions AWS infrastructure (network, compute, access, DNS) **via** Terraform (primary + standby environments).
2. Bootstraps a self-managed Kubernetes cluster on EC2 **via** Ansible (kubeadm pattern).
3. Installs CI/CD (Jenkins) and wires it into the cluster **using** Groovy initialization scripts.
4. Deploys data and metrics collectors, an LSTM model service, observability (Prometheus stack), backup/restore (Velero), chaos/testing, and an event trigger (Node.js).
5. Implements disaster recovery via Velero, a “standby” Terraform stack, plus reproducible Ansible runs.
6. Integrates secrets, (OIDC), and templated deployment artifacts for consistent promotion.

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
1. **Deterministic** environment **recreation** (infra, platform, plus workloads).
2. Automated CI/CD bootstrap with minimal manual **credential injection**.
3. Observability-first: metrics, logging (**implied**).
4. Predictive resilience via ML (**LSTM**) leveraging historical performance metrics.
5. Disaster recovery readiness (infrastructure dual definition, **Velero**, plus recovery playbooks).
6. Event-driven operations (Node.js trigger **bridging external systems** to Jenkins).
7. Secure secret handling and identity federation (**Vault/secret** modules).

## 4. Information Flow
1. **Provisioning**:
   - Terraform applies → creates VPC, subnets, security groups, EC2, ALB, DNS entries.
   - Outputs: IPs, DNS names, instance attributes → fed to Ansible (either via dynamic inventory generation or variable outputs passed manually/CI).

2. **Cluster Bootstrap**:
   - Ansible runs: container runtime → kubeadm init → control plane config → join workers → install CNI (implied in `setup_kubetools.yml`) → Helm installed.

3. **CI/CD Enablement**:
   - Jenkins installed (Ansible `install_jenkins.yml`).
   - Plugins & custom Groovy seeds configure:
     - Credentials (cloud, kubeconfig, registry, OIDC).
     - Kubernetes cloud integration for dynamic agents.
     - Adds cluster kubeconfig (Groovy + ansible-provided file).
   - Jenkins obtains ability to run pipeline stages inside cluster or on ephemeral agents.

4. **Application & Services Deployment**:
   - Ansible templates dynamic manifests (e.g., metrics collector).
   - Jenkins or Ansible applies them via kubectl/Helm.
   - Node.js trigger service waits for external events (e.g., model retrain, metrics anomaly) → triggers Jenkins job → pipeline may redeploy model or rotate configurations.

5. **Observability Loop**:
   - Prometheus scrapes workloads & system metrics.
   - Metrics collector possibly normalizes or exports (to TSDB or intermediate store).
   - LSTM service ingests metric time series (batch or streaming) to produce anomaly/failure likelihood signals.
   - Alerts (Prometheus Alertmanager) route to Jenkins or trigger service → orchestrated remediation or DR readiness check.

6. **Backup & DR Path**:
   - Velero schedules periodic backups (cluster objects + PV snapshots).
   - On incident: standby Terraform environment applied → Ansible replays bootstrap (minus initial cluster data if restoring).
   - Velero restore phase → rehydrate Kubernetes objects → redeploy model + metrics pipeline → Node.js trigger reattached.
   - Secrets restored from vault module + Ansible `setup_vault.yml`.


## 5. Design Principles
1. **Separation of Concerns**: 
   - Terraform (**infra**) 
   - Ansible (**node & cluster config**) 
   - Jenkins (**delivery**) 
   - YAML manifests (**runtime workloads**)
2. Layered **Idempotence**: Each stage can be re-applied without destructive drift (except controlled updates).
3. **Declarative** Edge: Kubernetes manifests & Velero resources declare desired resilient state.
4. **Extensibility**: **Modular** directory **structure** (adding new services via new module/play, plus template).
5. DR **Parity**: **Standby stack mirrors** primary for RPO/RTO optimization.
6. **Security**-by-**Initialization**: Groovy **bootstraps credentials early** to avoid manual console steps.
7. **Predictive Ops**: Integration of ML (**LSTM**) into operational **feedback loop**.

## 6. Component Breakdown
1. **Terraform Root** (`main.tf`, `locals.tf`, `providers.tf`, `variables.tf`, modules/*): orchestrates region/provider config, **passes outputs to modules.**
2. **Module:** `ec2/` (cluster & service hosts, networking, ALB).
3. **Module:** `aws_openid/` (assumed OIDC provider + trust relationships for roles).
4. **Module (optional):** `name_dot_com/` (DNS zone + record management).
5. **Module:** `secret_vaults/` (abstract **secret store** integration).
6. **Module:** `ansible_setup` / `ansible_run` (provisions context or triggers **remote execution** wrapper → **Ansible**).
7. **Ansible Tasks:** granular operational scripts (**Docker/containerd**, **kube** tools, **join logic**, **plugins**, **velero**, **vault**, **updates**).
8. **Templates**: environment variable **injection** & deployment **substitution logic**.
9. **Groovy Scripts**: Jenkins **dynamic** configuration at **startup** (**credentials**, **k8s cloud**, **OIDC**).
10. **Node.js Trigger**: Event **ingress** plus pipeline **invocation**.
11. **Observability Config**: `values-prometheus.yaml` influences **retention**, **scrape intervals**, **exporters**.
12. **Backup Config**: `velero.yml` defines provider (e.g., **S3 bucket**), **schedules**, restore **hooks**.
13. **ML & Data Manifests**: Kubernetes deployments for **LSTM** model (served with Python), m**etric ingestion**, plus **data sync pipeline**.

## 7. Disaster Recovery Mechanism
- **Data Layer**: Velero object, plus volume snapshots.
- **Infra Layer**: “standby_terraform” **replicates** network & compute skeleton.
- **Control Layer**: Ansible `setup_recovery.yml` **reconstructs** cluster **baseline**, then Velero **restore**.
- **Application Layer**: Jenkins **redeploys** pipelines; **metrics**, **model** redeployed; **triggers re-register**.
- **Validation Loop**: Observability & LSTM anomaly detection confirm **restored service health**.

## 8. Unique Mechanisms / Cross‑Cutting Patterns
1. **Dual environment Terraform** (primary, plus standby) embedded in same repo for synchronous evolution.
2. **Unified bootstrap chain**: Terraform **outputs** → Ansible **tasks** → Jenkins **Groovy injection** → Kubernetes **dynamic agents & workloads**.
3. **ML‑in‑the‑loop** for **reliability** (LSTM not just app feature, but **platform feedback**).
4. **Template** bridging (**Jinja2**) to keep Kubernetes specs **environment-agnostic until late binding.**
5. **Event-driven CI triggers** (**Node.js**) decoupling **external** stimuli **from Jenkins** internal APIs.
6. **DR-as-Code**: Recovery **playbooks** plus **backup manifests** versioned **alongside provisioning**.
7. Security instrumentation at bootstrap (**OIDC** & **audit policy**) rather than post-hoc hardening.

## 9. End-to-End Technical Walkthrough 
1. Run Terraform (**primary**): builds infra and outputs **addresses**.
2. Run Ansible: sets up runtime (**containerd**, **kubeadm init**, **joins**, **Helm**, **Jenkins**, **Velero**).
3. Jenkins starts: Groovy scripts add **kubrnetes cloud** plus **credentials**.
4. Deploy **Prometheus stack**, **(custom) metrics collector**, **data sync**, **model service**, **trigger service**.
5. Metrics flow into Prometheus + collector; model consumes time series; trigger listens for events.
6. **Velero** runs scheduled backups; standby environment kept in parity code-wise.
7. On anomaly: **LSTM** flags issue → **Jenkins pipeline** can initiate remedial tasks (redeploy, scale, or DR simulation).
8. On failure: apply **standby Terraform**, run **recovery Ansible**, restore **via Velero**, **resume workloads**, validate **via metrics** plus **model**.

## 10. Technical Goals Coverage
1. **Automation**: Terraform, Ansible, Groovy plus nodejs triggers.
2. **Observability**: Prometheus, audit, plus custom collector.
3. **Resilience**: Chaos testing scaffold, ML anomaly detection, Velero plus standby infra.
4. **Security**: OIDC, secrets vault integration, controlled kubeconfig provisioning.
5. **Reproducibility**: Idempotent layered code and versioned manifests.
6. **Extensibility**: Modular decomposition (add new module/play/service without refactor).

## 11. Summary
The infra directory implements a: 
1. multi-layered **IaC** + **configuration** + **runtime deployment** system 
2. This system is focused on **resilient Kubernetes operations**.
3. The system embeddes:
   - **ML-driven** anomaly detection
   - **automated** CI/CD provisioning
   - **event-triggered** recovery workflows 
   - **disaster recovery** readiness (forecasting)
4. Tying together the following into a cohesive, reproducible architecture: 
   - Terraform (**infra**)
   - Ansible (**config**)
   - Jenkins (**delivery**, **recovery control plane**)
   - Kubernetes (**runtime**)
   - Velero (**DR backups**)
   - Prometheus (**observability**) 
   - an LSTM model (**predictive** resilience/**forecasting**) 

