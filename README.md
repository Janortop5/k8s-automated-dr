# KIDR MANUAL: Inference Driven Kubernetes Disaster Recovery System 
## 1. High-Level System Concept
An **automated** end‑to‑end **platform** that:
1. Provisions **AWS infrastructure** (network, compute, access, DNS) **via** Terraform (primary + standby environments).
2. Bootstraps a **self-managed Kubernetes cluster** on EC2 **via** Ansible (kubeadm pattern).
3. **(Installs CI/CD (Jenkins)** and wires it into the cluster (jenkins-k8s-agent) **using** Groovy initialization scripts.
4. **Deploys data and metrics collectors**, an **LSTM model service**, observability (Prometheus stack), backup/restore (Velero), chaos/testing, and an event trigger (Node.js).
5. **Implements disaster recovery via** Velero, a “standby” Terraform stack, **plus** reproducible Ansible runs.
6. **Integrates secrets**, (OIDC), and templated deployment artifacts for consistent promotion.

## 2. Layered Architecture
1. **Foundation** (Terraform):
   - Remote state + backend **separation**.
   - VPC, subnets, security groups, ALB, EC2 (control plane & workers, Jenkins host) -> **Logical Network Environment.**
   - DNS (Name.com module) or **public wildcard domains for external access** (Jenkins + trigger service endpoints).
   - Bare OIDC module for **future identity integration** (Jenkins or cluster access).
   - Secret **vault** module(s) for **external secret stores.**
   - Separate **“standby_terraform”** for DR region or cold/warm failover.

2. **Configuration** (Ansible):
   - Inventory + host_vars for **role specialization** (Jenkins **node**, master **node** and worker (cluster) **nodes**).
   - Task files **split by concern**: container runtime (`setup_containerd.yml`), kube toolchain, kubeadm bootstrap, join workers, Helm installation, Jenkins setup, plugin provisioning, Velero install, Vault integration, metrics collector update, recovery bootstrap → **Ansible task files.**
   - Group vars (`secrets.yml`) **encrypted** (Ansible Vault) to manage **credentials**.
   - Jinja2 **templates** (e.g., `metrics_collector_deployment.yaml.j2`, `nodejs-trigger.env.j2`) enabling **environment-specific artifacts** emitted during runs.

3. **Orchestration Hooks** (Groovy + Node.js):
   - Groovy **startup scripts** (`add-kubeconfig.groovy`, `configure-k8s-cloud.groovy`, `create-credentials.groovy`, `oidc-init.groovy`) **embed** cluster **credentials**, **add cloud provider**, **create** Jenkins **credentials**, configure OIDC integration.
   - Node.js **trigger service** (`trigger/index.js`, `package.json`) acts as an **inbound event bridge** (e.g., webhook → Jenkins **job trigger** or model **inference pipeline**).

4. **Kubernetes Workloads** (YAML):
   - **Metrics collector** (`files/k8s-collector/metric_collector_deployment.yml` & templated variant) gathers **cluster/deployment metrics.**
   - **Data sync** (`k8s-metrics-data/data-sync.yml`) **loads** or **transfers data** into storage **for ML or backup.**
   - **LSTM model deployment** (`k8s-model/lstm_model_deployment.yml`) **exposes predictive service** (e.g., anomaly or recovery risk scoring).
   - **Observability** (`k8s-observability/values-prometheus.yaml`) extends **Prometheus stack** (scrape configs, retention, alerting).
   - **Chaos testing** placeholder directory for resilience **experiments** (**injecting faults**).
   - **Backup** (`velero.yml`) installs Velero + schedules + storage provider **configuration**.
   - **Audit policy** (`k8s-metrics-data/audit-policy.yaml`) adds **security** + **compliance** signal **stream**.

5. **Disaster Recovery:**
   - Velero **snapshots of cluster state** (via API) & persistent volumes (**exported object storage**).
   - **Standby** Terraform infra **enables** **rapid redeploy + restore sequence**.
   - Ansible `setup_recovery.yml` + `setup_vault.yml` **orchestrate secret persistence** and **cluster state rebuild**.
   - **LSTM** model + metrics **help** drive **proactive readiness** or **to detect abnormalities prompting DR actions.**

## 3. Technical Goals
1. **Deterministic** environment **recreation** (infra, platform, plus workloads).
2. **Automated CI/CD bootstrap** with **credential injection**.
3. **Observability-first**: metrics, logging (**implied**).
4. **Predictive** resilience via ML (**LSTM**) **leveraging historical** performance **metrics.**
5. **Disaster** recovery **readiness** (**dual infrastructure** definition, **Velero**, plus **recovery playbooks & pipelines**).
6. **Event-driven** operations (Node.js trigger **bridging external systems** to Jenkins).
7. **Secure secret handling** and identity federation (**Vault/secret modules**).

## 4. Information Flow
1. **Provisioning**:
   - Terraform applies → creates VPC, subnets, security groups, EC2, ALB, DNS entries.
   - Outputs: IPs, DNS names, instance attributes → fed to Ansible (via dynamic inventory generation plus outputs-led  variable-files generation).

2. **Cluster Bootstrap**:
   - Ansible runs: container runtime → kubeadm init → control plane config → join workers → install CNI (implied in `setup_kubetools.yml`) → Helm installed → Helm installations.

3. **CI/CD Enablement**:
   - Jenkins installed (Ansible `install_jenkins.yml`).
   - Plugins & custom Groovy seeds set to configure:
     - Credentials (cloud, kubeconfig, registry, OIDC).
     - Kubernetes cloud integration for dynamic agents.
     - Adds cluster kubeconfig (Groovy + ansible-provided file).
   - Jenkins obtains ability to run pipeline stages inside cluster or on ephemeral agents.

4. **Application & Services Deployment**:
   - Ansible templates dynamic manifests (e.g., metrics collector).
   - Jenkins or Ansible applies them via kubectl/Helm.
   - Node.js trigger service waits for external events (e.g., model retrain, metrics anomaly) → triggers Jenkins job → pipeline may redeploy model or rotate configurations or initialize recovery.

5. **Observability Loop**:
   - Prometheus scrapes workloads & system metrics.
   - Metrics collector normalizes or exports (to TSDB or intermediate store).
   - LSTM service ingests metric time series (batch or streaming) to produce anomaly/failure likelihood signals.
   - Alerts (Prometheus Alertmanager) route to Jenkins (trigger service) → orchestrated remediation or DR readiness check.

6. **Backup & DR Path**:
   - Velero schedules periodic backups (cluster objects + PV snapshots).
   - On incident: standby Terraform environment applied → Ansible replays bootstrap (minus initial cluster data if restoring).
   - Velero restore phase → rehydrate Kubernetes objects → redeploy kubernetes deployments → redeploy model + metrics pipeline → Node.js trigger reattached.
   - Secrets restored from jenkins situated terraform vault → vault module + Ansible `setup_vault.yml`.

## 5. Design Principles
1. **Separation of Concerns**: 
   - Terraform (**infra**) 
   - Ansible (**node & cluster config**) 
   - Jenkins (**delivery**) 
   - YAML manifests (**runtime workloads**)
2. Some Layered **Idempotence**: Each stage except implied run-once stages can be re-applied without destructive drift (also except controlled updates).
3. **Declarative** Edge: Kubernetes manifests & Velero resources declare desired resilient state.
4. **Extensibility**: **Modular** directory **structure** (adding new services via new module/play, plus template).
5. DR **Parity**: **Standby stack mirrors primary** for RPO/RTO optimization.
6. **Security**-by-**Initialization**: Groovy **bootstraps credentials early** to avoid manual console steps.
7. **Predictive Ops**: Integration of **ML (LSTM**) into operational **feedback loop**.

## 6. Component Breakdown
1. **Terraform Root** (`main.tf`, `locals.tf`, `providers.tf`, `variables.tf`, modules/*): orchestrates region/provider config, **passes outputs to modules** (plus **ansible tasks**).
2. **Module:** `ec2/` (cluster & service hosts, networking, ALB).
3. **Module:** `aws_openid/` (assumed OIDC provider + trust relationships for roles).
4. **Module (optional):** `name_dot_com/` (DNS zone + record management).
5. **Module:** `secret_vaults/` (**abstract secret store** integration).
6. **Module:** `ansible_setup` / `ansible_run` (provisions context or triggers **remote execution** wrapper → **triggers Ansible**).
7. **Ansible Tasks:** granular operational scripts (**Docker/containerd**, **kube** tools, **join logic**, **jenkins (plus plugins)**, **velero**, **vault**, **updates**).
8. **Templates**: environment **variable injection** & deployment **substitution logic**.
9. **Groovy Scripts**: Jenkins **dynamic configuration at startup** (**credentials**, **k8s cloud**, **OIDC**).
10. **Node.js Trigger**: **Event ingress** plus **pipeline invocation**.
11. **Observability Config**: `values-prometheus.yaml` influences **retention**, **scrape intervals**, **exporters**.
12. **Backup Config**: `velero.yml` defines provider (e.g., **S3 bucket**), kubernetes **schedules**, **restore hooks**.
13. **ML & Data Manifests**: Kubernetes **deployments for LSTM** model (served with **Python**), **metric ingestion**, plus **data sync** pipeline.

## 7. Disaster Recovery Mechanism
- **Data Layer**: Velero **object**, plus **volume snapshots**.
- **Infra Layer**: “standby_terraform” **replicates** network & compute skeleton.
- **Control Layer**: Ansible `setup_recovery.yml` **reconstructs** cluster **baseline**, then Velero **restore**.
- **Application Layer**: **Jenkins redeploys pipelines**; metrics, model redeployed; **triggers get re-registered**.
- **Validation Loop**: Observability & LSTM anomaly detection confirm **restored service health**.

## 8. Unique Mechanisms / Cross‑Cutting Patterns
1. **Dual environment Terraform** (primary, plus standby) **embedded in same repo** for synchronous evolution.
2. **Unified bootstrap chain**: Terraform **outputs** → Ansible **tasks** → Jenkins Groovy's **credentials injection** → Kubernetes **dynamic agents & workloads**.
3. **ML‑in‑the‑loop** for **reliability** (**LSTM based** not just app feature, but **platform feedback**).
4. **Template** bridging (Jinja2) to **keep Kubernetes specs environment-agnostic until late binding.**
5. **Event-driven CI** triggers (Node.js) **decoupling external stimuli from Jenkins internal APIs**.
6. **DR-as-Code**: **Recovery playbooks** plus **backup manifests** versioned **alongside provisioning**.
7. **Security** instrumentation **at bootstrap (Secrets vaults, audit policy & OIDC)** rather than post-hoc hardening.

## 9. End-to-End Technical Walkthrough 
1. **Run Terraform** (**primary**): **builds** infra **and outputs** addresses.
2. **Run Ansible**: sets up **runtime** (**containerd**, **kubeadm init**, **joins**, **Helm**, **Jenkins**, **Velero**).
3. **Jenkins starts**: Groovy scripts **add kubrnetes cloud** plus **credentials**.
4. **Deploy Prometheus stack**, **(custom) metrics collector**, **data sync**, **model service**, **trigger service**.
5. **Metrics flow** into Prometheus + collector; **model consumes** time series; **trigger listens** for events.
6. **Velero runs** scheduled backups; **standby environment kept in parity** code-wise.
7. **On anomaly**: **LSTM flags** issue → **Jenkins pipeline** can **initiate remedial tasks** (redeploy, scale, or DR simulation).
8. **On failure**: applies **standby Terraform**, run **recovery Ansible**, **restore via Velero**, **resume workloads**, **validate via metrics** plus **model**.

## 10. Technical Goals Coverage
1. **Automation**: Terraform, Ansible, Groovy plus nodejs triggers.
2. **Observability**: Prometheus, audit, plus custom collector.
3. **Resilience**: Chaos testing scaffold, ML anomaly detection, Velero plus standby infra.
4. **Security**: secrets vault integration, controlled kubeconfig provisioning, OIDC.
5. **Reproducibility**: Semi-idempotent layered code and versioned manifests.
6. **Extensibility**: Modular decomposition (add new module/play/service without refactor).

## 11. Summary
The infra directory implements a: 
1. **multi-layered** IaC + configuration + runtime deployment **system** 
2. This system is **focused on resilient Kubernetes operations**.
3. The system **embeddes**:
   - **ML-driven** anomaly detection
   - **automated** CI/CD provisioning
   - **event-triggered** recovery workflows 
   - **disaster recovery readiness** (forecasting)
4. **Tying together** the following into **a cohesive, reproducible architecture**: 
   - Terraform (**infra**)
   - Ansible (**config**)
   - Jenkins (**delivery**, **recovery control plane**)
   - Kubernetes (**runtime**)
   - Velero (**DR backups**)
   - Prometheus (**observability**) 
   - an LSTM model (**predictive resilience/forecasting**) 

## LSTM DR Notebook

#### Overview

This Jupyter notebook implements a proof-of-concept for an automated disaster recovery system for Kubernetes clusters using Long Short-Term Memory (LSTM) neural networks. The notebook covers:

1. **Data Loading and Preprocessing**: Loading the Kubernetes performance metrics dataset, cleaning timestamps, handling missing values, resampling time-series data, and scaling features and targets.
2. **LSTM Model Architecture**: Defining and instantiating an LSTM-based regression model to predict CPU and memory usage at the pod level.
3. **Model Training and Evaluation**: (Section in notebook) Training the LSTM on historical metrics, visualizing loss curves, and evaluating prediction accuracy.
4. **Disaster Prediction and Alerting System**: Generating alerts based on model predictions exceeding predefined thresholds and simulating recovery actions.

#### Repository Structure
`/k8s-lstm/notebook/`
1. lstm-disaster-recovery.ipynb → Main notebook (~few MBs); contains code, visualizations & annotations
2. data → Raw & processed data (~MBs to GBs); CSVs, JSON, etc.
3. model → Trained models (~10MBs to 100s of MBs); saved LSTM weights or checkpoints
4. scalers → Serialized scalers (~KBs); e.g., pickle files for data normalization
5. `requirements.in` → Dependency list (~1–5 KB); pip installable libraries
6. `README.md` → Project overview (~1–10 KB); explains setup, usage & goals

#### 🛠️ Prerequisites
1. **Python 3.11**  
2. **Conda** (optional, recommended on macOS → running notebook on macOS)  

#### Dependencies

This notebook requires the following Python libraries:

1. Python 3.11
2. pandas>=1.3.0
3. numpy>=1.21.0
4. scikit-learn>=1.0.0
5. matplotlib>=3.4.0
6. notebook>=6.5.0
7. seaborn>=0.13.2
8. tensorflow==2.15.0

#### To run locally → Option A: Conda (recommended)

1. Create & activate:
   ```bash
   conda env create -f environment.yml
   conda activate k8s-lstm
   ```

2. Register the env as Jupyter Kernel:
    ```
    pip install ipykernel
    python -m ipykernel install --user \
        --name k8s-lstm --display-name "Python (fyp)"
    ```

3. If you update requirements.txt, sync with:
    ```bash
    Edit
    pip install -r notebook/requirements.txt
    ```

#### To run locally → Option B: Pip only
1. Create a venv and activate it:
    ```bash
    python3.11 -m venv .venv
    source .venv/bin/activate
    ```

2. Install dependencies:

    ```bash
    pip install --upgrade pip
    pip install -r notebook/requirements.txt
    ```

3. (Optional) Register as a kernel:
    ```bash
    pip install ipykernel
    python -m ipykernel install --user \
        --name k8s-lstm --display-name "Python (fyp)"
    ```

#### Dataset

The notebook expects a CSV file containing Kubernetes performance metrics with at least the following columns:

* `timestamp`: DateTime string for metric recording times.
* `pod_name`: Identifier for each pod.
* `cpu_usage`: CPU usage metric (e.g., cores).
* `memory_usage`: Memory usage metric (e.g., MiB).

data(set) paths:
- data ingestion: `/data/kubernetes_performance_metrics_dataset.csv`
- model save: `/data/cluster/`

Adjust the `csv_path` variable in the DataProcessor instantiation if needed.

#### Running the Notebook
1. Change into the notebook folder so that os.getcwd() points at …/k8s-lstm/notebook:
    ```bash
    cd k8s-lstm/notebook
    ```

2. Launch Jupyter:
    ```bash
    jupyter notebook
    ```

3. Select the your `conda/env` name kernel.

4. Run All cells top-to-bottom (ModelManager is defined first).

5. **Run all cells** to preprocess data, train the model, evaluate performance, and simulate disaster alerts.

#### 💾 Model Saving & Loading

After “Run All” you’ll see:

```
models/
├─ kubernetes_lstm_disaster_recovery.h5
└─ kubernetes_lstm_disaster_recovery_architecture.json
```

## LSTM Deployment

#### Overview

The model is deployed in the kubernetes cluster and becomes the inference layer. This layer server as the anomaly prediction layer fo the cluster. Predicts failures crashes and an important component of automated disaster recovery.

#### Repository Structure
`/k8s-lstm/`
1. deployment → `main.py` that serves model.
2. metrics-collector → `alert_manager.py` contains the logic for predictions.
3. notebook → a proof-of-concept for an automated dr system for k8s clusters using Long Short-Term Memory (LSTM) neural networks.
4. Dockerfile → to build docker images of model and metrics collector that are specified in `metric_collector_deployment.yml` kubernetes deployment manifests.

# How to run the system
## Terraform
This Terraform Configuration creates a Functional Kubeadm Kubernetes Environment and a Jenkins CI Server, both on AWS.

#### Prerequisite
- Installation of **Docker** locally
- Installation of **Terraform** locally
- Instalation of **Ansibe** locally
- Docker PAT
- Github PAT (recommended) or password

### How to use the terraform IaC
#### First create Terraform vault.
1. Add environment variables.
```bash
export TF_VAR_vault_address='http://127.0.0.1:8200'
export TF_VAR_ansible_vault_password='your-ansible-vault-token'
export TF_VAR_vault_token='your-tf-vault-token'
export TF_LOG=DEBUG
export vault_token='your-tf-vault-token'
export jenkins_username='your-jenkins-username'
export jenkins_password='your-jenkins-password'
export git_username='your-git-username'
export git_password='your-git-password'
export docker_username='your-docker-username'
export docker_password='your-docker-password'
export aws_access_key='your-access-key'
export aws_secret_access_key='your-secret-access-key'
```
2. Create terraform vault docker container.
```bash
docker ps -a --format '{{.Names}}' | grep -w tf_vault && docker start tf_vault || docker run -dit --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=0102911' --name 'tf_vault' -p 8200:8200 hashicorp/vault:latest
```
#### Test Vault Setup
1. **Create test password.**
```bash
docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/test username='admin' password='1234'"
```
2. **Test connection:** look for output -> `test_username = "admin"`
```
terraform init
terraform fmt
terraform plan

#Look for output -> test_username = "admin" -> connection success ✅
```
3. **Create TF Vault Secrets**
```bash
docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/aws access_key='${aws_access_key}' secret_key='${aws_secret_access_key}'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/velero bucket_name='velero-demo-01' region='us-west-2'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/remote vault_address='http://127.0.0.1:8200' vault_token='${vault_token}'"

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/jenkins -<<EOJSON
{
  "jenkins_username": "$jenkins_username",
  "jenkins_password": "$jenkins_password"
}
EOJSON
EOF

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/git_credentials -<<EOJSON
{
  "git_username": "$git_username",
  "git_password": "$git_password"
}
EOJSON
EOF

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/docker_credentials -<<EOJSON
{
  "docker_username": "$docker_username",
  "docker_password": "$docker_password"
}
EOJSON
EOF
```

#### Everything together
```bash
export TF_VAR_vault_address='http://127.0.0.1:8200'
export TF_VAR_ansible_vault_password='your-ansible-vault-token'
export TF_VAR_vault_token='your-tf-vault-token'
export TF_LOG=DEBUG
export vault_token='your-tf-vault-token'
export jenkins_username='your-jenkins-username'
export jenkins_password='your-jenkins-password'
export git_username='your-git-username'
export git_password='your-git-password'
export docker_username='your-docker-username'
export docker_password='your-docker-password'
export aws_access_key='your-access-key'
export aws_secret_access_key='your-secret-access-key'

docker ps -a --format '{{.Names}}' | grep -w tf_vault && docker start tf_vault || docker run -dit --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=0102911' --name 'tf_vault' -p 8200:8200 hashicorp/vault:latest

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/test username='admin' password='1234'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/aws access_key='${aws_access_key}' secret_key='${aws_secret_access_key}'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/velero bucket_name='velero-demo-01' region='us-west-2'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/remote vault_address='http://127.0.0.1:8200' vault_token='${vault_token}'"

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/jenkins -<<EOJSON
{
  "jenkins_username": "$jenkins_username",
  "jenkins_password": "$jenkins_password"
}
EOJSON
EOF

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/git_credentials -<<EOJSON
{
  "git_username": "$git_username",
  "git_password": "$git_password"
}
EOJSON
EOF

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/docker_credentials -<<EOJSON
{
  "docker_username": "$docker_username",
  "docker_password": "$docker_password"
}
EOJSON
EOF
```
#### Run the Terraform config
1. First, confirm aws profile and region. i.e.
```bash
aws configure # after, click **Enter**, **Enter**, **Enter** **Enter** -> if fields contain non-preferred or no values add new value before hitting enter.
```
2. Format, Validate, Initialize and run the Terraform Configuration.
```bash
terraform fmt                       # ensure code is in right format
terraform validate                  # validate code is correct
terraform init                      # intialize terraform

terraform plan -out .terraform.plan # view resources to be created.
terraform apply ".terraform.plan"   # apply the terraform configuration
```
3. **To replace an existing resource**
```bash
terraform plan -replace=" **resource_name** " -out .terraform.plan
terraform apply ".terraform.plan"
```
4. **To remove an existing resource from terraform state**
```
terraform state rm <resource name> # i.e. terraform state rm module.remote_state.aws_dynamodb_table.basic-dynamodb-table, terraform state rm module.remote_state.aws_s3_bucket.tf_backend_bucket
```
### Terraform Output
The terraform code output displays several important infrastructure information needed by the operator/user.
* instance_id → the instance_ids of all servers created on aws region
* public_ips → the public ips of all the servers
* check_ssh_script → a status script that allow you check if servers are ready for ssh connection
* master_public_ip → the elastic ip of the k8s master node
* worker_public_ips → the elastic ip of the k8s worker nodes
* jenkins_public_ip → the elastic ip of the jenkins node
* ansible_playbook_command → command to run the playbook outside terraform (optional: manual)
* cognito_user_pool_id → openid user pool
* cognito_metadata_url → openid metadata url
* cognito_client_id → openid client_id
* cognito_client_secret → openid client_secret
* jenkins_redirect_uri → openid redirect_url

## Standby Terraform
For our recovery environment, a standby Terraform configuration is made available:
- It contains the original terraform configuration **excluding** the Jenkins server's provisioning and setup, and `AWS OpenID`, and `Namedotcom` modules. 

They were determined as not needed for the standby environment. 
1. The standby terraform run is automated as part of the recovery (process) in created jenkins' `k8s-automated-dr` pipeline
2. The standby terraform runs in this pipeline. This pipeline has a trigger that comes from the primary cluster, handled by nodejs.
> NOTE: this standby environment is a Cold environment, to be triggered by a standby recovery environment request that comes from the primary cluster.

### How to run the Standby Terraform IaC Manually (Optional)
> If creating the Standby Environment MANUALLY

1. First, change Working directory. i.e.
```bash
cd standby_terraform
```
2. Second, run the terraform process.
```bash
terraform fmt                       # ensure code is in right format
terraform validate                  # validate code is correct
terraform init                      # intialize terraform

terraform plan -out .terraform.plan # view resources to be created.
terraform apply ".terraform.plan"   # apply the terraform configuration
```
3. To replace an existing resource
```bash
terraform plan -replace=" **resource_name** " -out .terraform.plan
terraform apply ".terraform.plan"
```
4. To remove an existing resource from terraform state
```bash
terraform state rm <resource-name> # i.e. terraform state rm module.remote_state.aws_s3_bucket.tf_backend_bucket, terraform state rm module.remote_state.aws_dynamodb_table.basic-dynamodb-table
```
## Ansible & Jenkins

1. Access the Jenkins server on `https://<jenkins-node-ip>.nip.io/` or `https://<jenkins-node-ip>.sslip.io/` → generated in ansible task output `Record winning domain (if any)`

2. Login using the `jenkins_username` and `jenkins_password` you set before running terraform. → Ansible creates admin user and installs plugins

3. The Ansible installs the following jenkins plugins for you
   - Kubernetes
   - Kuberntes client
   - Kubernetes credentials
   - Github
   - Docker pipeline
   - Git
   - Pipeline
4. The Ansible adds the following credentials to jenkins credentials
   - github credentials
   - dockerhub credentials
   - kubernetes credentials (kubeconfig, jenkins-kubeconfig)
   - aws credentials
   - ssh key
   - remote bucket details
5. The Ansible configures kubernetes cloud in jenkins
6. The ansible playbook outputs the following files
   - kubeconfig-<master_private_ip>.yaml
   - jenkins-kubeconfig.yaml

## Jenkins: Setup Steps
#### Easiest: *Multibranch Pipeline* (auto-discovers branches & PRs)

1. Jenkins dashboard → **New Item**
2. Name it **k8s-automated-dr**.  <- **THIS IS COMPULSORY FOR THE WEBHOOK URL** 
3. pick **Multibranch Pipeline** → OK
4. In **Branch Sources**:

   * **Add source → GitHub**
   * Credentials: choose your `github-pat`
   * Repository https: enter `<repo https clone url>`
5. 👇 Mode **by Jenkinsfile** and **script-file: Jenkinsfile**.
6. Apply and Save

After **Save** → Jenkins will scan the repo immediately, build any branch with a `Jenkinsfile`, and keep polling via the webhook.

#### To reclaim space on Jenkins server after build runs

```bash
sudo su - 

#!/bin/bash
docker system prune -af --volumes
rm -rf /var/lib/jenkins/workspace/* /var/lib/jenkins/tmp/*

# rebuild the workspace
sudo su - jenkins
mkdir -p /var/lib/jenkins/workspace/k8s-automated-dr-pipeline_main
```
Check below for step-by-step ⬇️

## Dashboards: View resource metrics
1. **Access Prometheus UI**
   a.
  Locally (if you have kubectl configured):
   ```bash
   kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
   # → browse http://localhost:9090
   ```

   b. **Via SSH tunnel (if you’ve SSH’d into a node):**
  First ssh into the node and run the port-foward command in step 1a, then run locally:
   ```bash
   ssh -N -L 9090:127.0.0.1:9090 ubuntu@<node-ip> -i k8s-cluster.pem
   # → browse http://localhost:9090
   ```

2. **Check Targets & Sample Queries**
   Targets: In Prometheus UI → Status → Targets

3. **Access Grafana UI**
  Locally (if you have kubectl configured): 
  a.
   ```bash
   kubectl -n monitoring port-forward svc/prometheus-grafana 10080:80
   # → browse http://localhost:9090
   ```
   b. **Via SSH tunnel (if you’ve SSH’d into a node):**
   First ssh into the node and run the port-foward command in step 3a, then run locally:
   ```bash
   ssh -N -L 10080:127.0.0.1:8080 ubuntu@<node-ip> -i k8s-cluster.pem
   # → browse http://localhost:8080
   ```
## Velero

Velero is a critical component of the disaster recovery system that:

1. **Backs up and restores** Kubernetes cluster resources and persistent volumes
2. **Enables disaster recovery** by providing point-in-time snapshots of the cluster state
3. **Facilitates cluster migration** between environments (primary to standby)
4. **Automates backup schedules** (configured for every 6 hours)

### Key Features
1. **Kubernetes-Native Backup**:
   - Captures all cluster resources (deployments, configmaps, secrets, etc.)
   - Backs up persistent volumes using cloud provider snapshots
   - Stores backups in S3-compatible object storage

2. **Disaster Recovery Capabilities**:
   - Restores entire cluster or selected namespaces
   - Preserves resource relationships during restore
   - Supports cross-cluster migration of workloads

3. **Integration with AWS**:
   - Uses AWS S3 buckets for backup storage
   - Leverages AWS EBS snapshots for persistent volume data
   - Securely accesses AWS resources using IAM roles

4. **Operational Features**:
   - CLI tool for manual backup/restore operations
   - Scheduled backups for consistent recovery points
   - Backup retention policies to manage storage usage

Velero serves as the foundation of the disaster recovery strategy, enabling rapid restoration of the Kubernetes cluster and its workloads in the standby environment when primary cluster failures occur.

## Node.js Trigger Service

The Node.js trigger service is a critical component of the automated disaster recovery system that:

1. **Acts as a middleware** between monitoring systems and Jenkins pipelines
2. **Provides a reliable queue-based system** for DR operations using Redis
3. **Securely manages credentials** via HashiCorp Vault integration
4. **Runs as a systemd service** on the Jenkins server

### Key Features
1. **API Endpoints**:
   - `/health` - Health check endpoint
   - `/trigger` - Main endpoint to queue DR jobs
   - `/queue/status` - Shows the current queue status
   - `/job/:jobId/status` - Shows status of a specific job

2. **Queue Management**:
   - Uses Redis to maintain job queues
   - Prevents overloading Jenkins with concurrent requests
   - Tracks job status throughout execution

3. **Automated DR Triggering**:
   - Initiates standby cluster deployment when primary cluster issues are detected
   - Passes configurable parameters to Jenkins pipelines:
     - `deploy_standby_only` - Deploy only the standby environment
     - `destroy_after_apply` - Clean up resources after testing
     - `skip_tests` - Skip test phases for faster deployment

4. **Integration**:
   - Connects to Jenkins via webhook API
   - Retrieves credentials securely from Vault
   - Can be triggered by monitoring alerts or manual requests

### Manual Trigger Example
To manually trigger the disaster recovery process, you can use the following curl command:

```bash
curl -X POST "<jenkins_live_domain>/trigger" \
  -H "Content-Type: application/json" \
  -H "Jenkins-Crumb: <crumb_token>" \
  -u "<jenkins_username>:<jenkins_webtoken>" \
  -d '{
    "parameters": {
      "deploy_standby_only": "true",
      "destroy_after_apply": "true",
      "skip_tests": "true"
    }
  }'
```

This service enables fully automated disaster recovery by providing a reliable mechanism to trigger the standby environment deployment when the primary cluster experiences issues.

## Chaos Mesh and Disaster Recovery Simulation

### Chaos Mesh
The system includes Chaos Mesh for chaos engineering experiments, but note that:
- The cluster already experience high CPU usage on t3 instance types without running chaos experiments
- Consider using larger instance types if you plan to run extensive chaos tests

### Standby Authentication
For standby environment authentication:
- The trigger URL needs to be exposed and added to Jenkins secrets
- Use the credential ID `jenkins-url` when setting up the authentication

### Simulating Disaster Recovery
To simulate a full disaster recovery scenario:

1. **Rebuild the metrics-collector container**:
   ```bash
   # Navigate to the metrics-collector directory
   cd k8s-lstm/metrics-collector/alert_manager.py
   
   # Modify the parameters in alert_manager.py to set deploy_standby to true
   # Look for the parameters section and change:
   # "deploy_standby_only": "false" to "deploy_standby_only": "true"
   
   # Rebuild and push the container
   docker build -t your-registry/metrics-collector:latest .
   docker push your-registry/metrics-collector:latest
   ```

2. **Monitor the Jenkins pipeline**:
   - When the metrics collector detects anomalies, it will trigger the Jenkins pipeline
   - With `deploy_standby_only` set to `true`, it will deploy the standby environment
   - You can monitor the progress in the Jenkins UI

3. **Verify the standby environment**:
   - After successful deployment, verify the standby environment is operational
   - Check that all critical services are running
   - Test the application functionality in the standby environment
  
# Manual Jenkins setup
Jenkins Credentials and Jenkins Kubernetes cloud automation currently fails. Here's a manual setup guide.
### Setup Jenkins for KIDR
AFTER RUNNING THE INFRA's TERRAFORM CODE AND ANSIBLE TASKS.

Below is the quickest path to hook k8s-automated-dr Jenkins box up to its GitHub repo so every push kicks off a build.

## 0  Login and Create User
1. Access the Jenkins server on `https://<jenkins-node-ip>.nip.io/`. <-- this is generated from the ansible output.
1. Copy the Initial Jenkins Admin password from the Ansible task 'Set Jenkins admin password fact' and paste in the Initial password page.
2. In the plugins page, select the option to install the suggested plugins.
3. Create the First Admin User and Password.

## 1  Install the needed plugins

> THESE PLUGINS ARE ALREADY PART OF THE SUGGESTED DEFAULT PLUGINS SO SKIP THIS STEP. IF NOT AVAILABLE (e.g Kubernetes plugin), MANUALLY INSTALL THEM.
1. **Manage Jenkins → Manage Plugins → Available**
2. Search and install (no restart required for recent LTS versions):

   * **Kubernetes** plugin (*add jenkins agents to kubernetes cluster*)
   * **Kubernetes** Client plugin (*enables jenkins remote actions on kubernetes cluster*)
   * **Kubernetes** Credentials plugin (*add credentials to jenkins and enable remote actions*)
   * **GitHub** plugin (*adds web-hooks endpoint & creds helpers*)
   * **Docker pipeline** plugin (*adds docker agent to pipeline*)
   * **Git** plugin (already bundled in most installs)
   * **Pipeline** (if you want to use a `Jenkinsfile`, highly recommended)


## 2A  Create a GitHub token for Jenkins

1. In GitHub **Settings → Developer settings → Personal access tokens**
2. *Generate new token (classic)* → give it:

   * **`repo`** (read your code)
   * **`admin:repo_hook`** (set up the webhook automatically)
     (*If you’d rather add the webhook by hand you can skip this scope.*)
3. Copy the token – you’ll only see it once.

## 2B  Create a Registry (e.g. Dockerhub) token for Jenkins

1. In Dockerhub **Click on Avatar → Account settings → Personal access tokens**
2. *Generate new token* → give it:

   * **`Read & Write`** (read and write to your registry repositories)
   * *access token description* → k8s-automated-dr
3. Copy the token – you’ll only see it once.



## 3A  Add the token to Jenkins credentials

1. **Manage Jenkins → Credentials → (choose global store)**
2. **Add Credentials (GitHub)**

   * Kind: **username with password**
   * Username: *paste username*
   * Password: *paste the PAT*
   * ID / Description: `github-pat` 
3. **Repeat for Dockerhub**
4. **Add Credentials (Kubernetes)**: It will be generated in ansible directory after running terraform/ansible

   * a. 
      * Kind: **secret file**
      * Filename: *kubeconfig-<>.yaml*
      * ID / Description: `kubeconfig-prod` 
   * b.
      * Kind: **secret file**
      * Filename: *jenkins-kubeconfig.yaml*
      * ID / Description: `k8s-jenkins-agent`     
> KUBECONFIG IS GENERATED IN THE ANSIBLE OUTPUT IN TASK * Show local kubeconfig path and copy/paste hint * in tasks file '*bootstrap_master.yml*'
5. **Add ssh key**

   * a. 
      * Kind: **secret text**
      * Filename: k8s-cluster.pem
      * ID / Description: `my-ssh-key`
> NOTE: The ssh key for the main environment will be created in the infra/ directory and for the standby environment in infra/terraform/standby_terraform/ directory.
6. **AWS Details**
   * a. 
      * Kind: **secret text**
      * Filename: *aws_access_key*
      * ID / Description: `my-ssh-key`
   * b.
      * Kind: **secret text**
      * Filename: *aws_secret_key*
      * ID / Description: `aws_secret_key`   
   * b.
      * Kind: **secret text**
      * Filename: *backup_bucket*
      * ID / Description: `backup_bucket`   
   * b.
      * Kind: **secret text**
      * Filename: *backup_bucket_region*
      * ID / Description: `backup_bucket_region`   

## 3B Configure Kubernetes Cloud in Jenkins
1. Go to Manage Jenkins → Clouds → New Cloud
2. Add a new Kubernetes cloud:

   * Cloud name -> `k8s-automated-dr`
   * Type -> kubernetes
3. Actions Needed:

   * Kubernetes URL                       <- Find this in generated kubeconfig in ansible directory
   * Attach your credentials
   * Customize pod template if needed     <- Configuartion still valid if NOT set.
   * Test the connection


> DIRECTIONS FOR THE ABOVE STEPS

Where the token ends up & how Jenkins consumes it?
* Playbook output
The task writes a file named, e.g.,

```bash
./kubeconfig-<master_private_ip>.yaml
./jenkins-kubeconfig.yaml
```

* Inside you will see:

```yaml
users:
- name: jenkins
  user:
    token: eyJhbGciOiJSUzI1NiIsImtpZCI6I…   # ← plain JWT
```

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tL
```

The CA bundle is already Base-64, but the token is plain text – that’s
exactly what the Kubernetes API expects.

* Upload the file to Jenkins once: Manage Jenkins → Manage Credentials → (Global) → Add Credentials (Check steps above)

* Tell the Kubernetes Cloud to use it: Manage Jenkins → Manage Nodes and Clouds → Configure Clouds → Kubernetes

* Field	What to enter. 
   * Kubernetes URL	https://**master-PRIVATE-IP**:6443.
   * Kubernetes server certificate key -> leave empty`.
   * Kubernetes Namespace -> jenkins
   * Agent Docker Registry -> docker.io
   * Credentials	choose k8s-jenkins-agent.
   * WebSocket ? Direct Connection -> Select WebSocket
   * Jenkins url -> http://**jenkins_private_ip**:8080 (copy from automatically generated `/group_vars/all.yml`)
   * Transfer proxy related environment variables form controller to agent -> leave off
   * Restrict pipeline support to authorized folder -> leave off
   * Defaults provider Template? -> Leave Blank
   * Enable garbage collection -> leave off
* Save. The plugin loads the kube-config, extracts the token & CA, and starts using the API immediately.

   * Nothing else to copy – the token Jenkins needs is already inside the file.
   * Whenever the playbook refreshes the token (e.g. re-run in 24 h) just upload
   * the new kube-config or replace the credential file; Jenkins picks it up without a restart.

> NOTE: THIS STEPS 3A.4,5 TO BE CREATED AGAIN WHEN A STANDBY ENVIRONMENT IS CREATED.
## 4  Create the job

### Easiest: *Multibranch Pipeline* (auto-discovers branches & PRs)

1. Jenkins dashboard → **New Item**
2. Name it **k8s-automated-dr**.  <- THIS IS COMPULSORY FOR THE WEBHOOK URL 
3. pick **Multibranch Pipeline** → OK
4. In **Branch Sources**:

   * **Add source → GitHub**
   * Credentials: choose your `github-pat`
   * Repository https: enter `<repo https clone url>`
5. 👇 Mode **by Jenkinsfile** and **script-file: Jenkinsfile**.
6. * Apply and Save

After **Save** → Jenkins will scan the repo immediately, build any branch with a `Jenkinsfile`, and keep polling via the webhook.

## 5  Add (or verify) the webhook

*If you gave the token the `admin:repo_hook` scope, Jenkins auto-creates it the first time the job saves. If not:*

1. GitHub repo → **Settings → Webhooks** → Add webhook
2. **Payload URL:** `https://<jenkins-host>/github-webhook/`
3. **Content-type:** `application/json`
4. **Secret:** *(leave blank or set and mirror in the job settings)*
5. **Events:** **Just the push event** (and optionally PR events) → Save.

GitHub will ping the endpoint; you should see “*Payload delivered*” and a 200‐OK response.

#### Reclaim Space on Jenkins Server

```bash
sudo su - 

#!/bin/bash
docker system prune -af --volumes
rm -rf /var/lib/jenkins/workspace/* /var/lib/jenkins/tmp/*

# rebuild the workspace
sudo su - jenkins
mkdir -p /var/lib/jenkins/workspace/k8s-automated-dr-pipeline_main
```
