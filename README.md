# k8s-automated-dr
*Fun project to develop, learn and build.

## Run Terraform
First, configure aws cli in control environment.
```
aws configure
```

Run Terraform plan, to see resources to be created, and store output in `.terraform.plan`

```
terraform plan -out .terraform.plan
```

Apply Terraform

```
terraform apply ".terraform.plan"
```
A successful Terraform run here, creates ec2 resources and kubeAdm resources. Together, the result is a KubeAdm Cluster on AWS. 

> The `ec2` module creates necessary resources on AWS. The `kubeadm` module runs the ansible playbook placed in this repository, the ansible playbook automates provisioning of KubeAdm kubernetes cluster.

## K8S LSTM Pipeline CI/CD Setup

This repository contains a Jenkins pipeline for building and deploying an LSTM data pipeline on Kubernetes.

### Project Structure

```
/ (root)
├── Jenkinsfile                  # Jenkins pipeline definition
│
└── k8s-lstm-pipeline/           # Main project directory
  ├── kubernetes/              # All Kubernetes-related files
  │   ├── collect_metrics.py   # Python script for metrics collection
  │   ├── requirements.txt     # Python dependencies
  │   ├── Dockerfile           # Dockerfile for the metrics collector
  │   │
  │   └── templates/           # Kubernetes YAML templates
  │       ├── persistent-volume.yaml
  │       ├── persistent-volume-claim.yaml
  │       └── data-collector.yaml
  │
  └── ci/                      # CI/CD specific configurations
    └── config.properties    # Configuration properties
```

### Quick Start

1. Configure your environment variables in `k8s-lstm-pipeline/ci/config.properties`
2. Set up Jenkins with the Kubernetes plugin
3. Create credentials in Jenkins for Docker registry and Kubernetes
4. Create a new pipeline job pointing to this repository

### Requirements

- Jenkins with Kubernetes plugin
- Docker registry access
- Kubernetes cluster access

## Ansible Directory

The Ansible directory contains configurations for infrastructure management and automation.

### Project Structure
```
/ansible
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
│   └── setup_kubetools.yml     
│
├── playbook.yml              # Playbook for automated kubeadm setup
│
└── training                  # Hosts file
```

## Terraform Directory

The Terraform directory contains infrastructure-as-code for provisioning cloud resources.

```
/terraform
├── modules/             # Reusable Terraform containerd-setup         # deprecated
│
├── examples/  
│
├── variables.tf         # Input variables
├── outputs.tf           # Output variables
└── main.tf              # Main Terraform configuration
```

##  Monitoring

The monitoring setup uses Prometheus, Grafana and Loki for observability:

```
/monitoring
├── prometheus.yml
└── promtail-config.yml
```

# TODO
### TEST ANSIBLE AND TERRAFORM CONFIGURATION AND CI PIPELINE

## Prerequisites

1. A running Jenkins server with the following plugins installed:
   - Pipeline
   - Kubernetes
   - Credentials
   - Docker Pipeline
   - Jenkins Kubernetes plugin

2. Access to a Kubernetes cluster (for Jenkins to deploy to)

3. Docker registry credentials

## Setup Steps

### 1. Create Jenkins Credentials

Create the following credentials in Jenkins:

- **docker-registry-url**: Secret text containing your Docker registry URL
- **docker-registry-credentials**: Username with password for your Docker registry login

### 2. Create the Pipeline Job

1. In Jenkins, click on "New Item"
2. Enter a name for your job (e.g., "k8s-lstm-pipeline")
3. Select "Pipeline" as the job type
4. Click "OK"

### 3. Configure the Pipeline

1. In the job configuration page, scroll down to the "Pipeline" section
2. Select "Pipeline script from SCM" if your Jenkinsfile will be stored in a repository
   - Specify your repository details
   - Path to Jenkinsfile: `Jenkinsfile`
3. Or select "Pipeline script" and paste the Jenkinsfile content directly

### 4. Set Up Template Files

The key to making this work similar to Ansible's variable substitution is:

1. Store your Kubernetes YAML files as templates in the `kubernetes/templates/` directory
2. Use environment variable placeholders (e.g., `${NAMESPACE}`, `${PV_SIZE}`) in these