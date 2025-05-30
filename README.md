# k8s-automated-dr
A Jenkins-driven pipeline builds a PyTorch LSTM anomaly detector on etcd metrics, deploys it to a kubeadm cluster, and a Kopf operator automatically triggers a safe etcd snapshot+restore when anomaly score > τ, all proved by a chaos test.

# Project Repo Layout
Below is the repository layout for the Automated DR project.
```
.
├── infra/
│   ├── terraform/        # 1 master + 2 worker (kubeadm), Jenkins
│   └── ansible/          # installs kubeadm, kube-prometheus-stack
├── jenkins/              # Jenkinsfile + seed job groovy
├── collector/
│   ├── Dockerfile
│   └── etcd_metrics_collector.py   # scrapes /metrics, pushes to Pushgateway
├── detector/
│   ├── Dockerfile
│   └── serve_lstm.py     # loads TorchScript model, exposes /score
├── operator/
│   ├── Dockerfile
│   └── dr_operator.py    # Kopf controller: watches /score, calls etcdctl
├── charts/
│   ├── collector/        # Helm sub-chart
│   ├── detector/
│   └── operator/
└── notebook/
    └── 01_etcd_lstm.ipynb
```

## Jenkins Directory Layout

The `jenkins` directory contains Jenkinsfile ci definitions and other needed files.
```
/jenkins
├── Jenkinsfile                  # Jenkins pipeline definition
├── config.properties        
└── loadProperties.groovy         # Main project directory
```

## Ansible Directory Layout

The `/infra/ansible/` directory contains configurations for kubeadm and jenkins provisioning.

```
/infra/ansible/
├── files/                    # files
├── group_vars/               # group variables
├── host_vars/                # Host variables
├── inventory/     
│
├── roles/                    # Host inventory files
│   ├── common/               # template files
│   └── k8s_lstm_pipeline/    # deprecated and moved to ci
│
├── tasks/                    # Ansible roles
│   ├── bootstrap_master.yml         
│   ├── containerd_setup.yml    
│   ├── install_docker.yml         
│   ├── install_monitoring_heml.yml
│   ├── join_workers.yml         
│   ├── setup_kubetool_pre_tasks.yml
│   ├── setup_kubetools.yml     
│   └── install_jenkins.yml
│
├── kubeadm.yml               # Playbook for automated kubeadm setup
├── jenkins.yml               # Playbook for automated jenkins setup
├── playbook.yml              # Playbook for automated kubeadm setup and jenkins
│
└── hosts                     # Hosts file automatically created by terraform
```

## Terraform Directory Layout

The `/infra/terraform/` directory contains infrastructure-as-code for provisioning cloud resources.

```
/infra/terraform/
├── modules/             # ec2, ansible_setup, ansible_run, open_id (for jenkins user pool)
│
├── variables.tf         # Input variables
├── outputs.tf           # Output variables
└── main.tf              # Main Terraform configuration
```
# TODO
### JENKINS PIPELINE, K8S-LSTM, OPERATOR, CHAOS TEST

#### 1. Validate OpenID module in /infra/terraform directory

#### 2. Create the Pipeline Job

#### 3. Configure the Pipeline

#### 4. Develop Pytorch LSTM

#### 5. Build Operator

#### 6. Perform Chaos test