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

## Jenkins: Manual Step/Setup
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
   ssh -N -L 10080:127.0.0.1:10080 ubuntu@<node-ip> -i k8s-cluster.pem
   # → browse http://localhost:10080
   ```
#### TODO: UPDATE SECURITY GROUP TO ALLOW 10080
## Velero