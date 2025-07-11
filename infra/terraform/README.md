# Terraform
This Terraform Configuration creates a Functional Kubeadm Kubernetes Environment and a Jenkins CI Server, both on AWS.

## How to use our terraform IaC
```bash
terraform fmt                       # ensure code is in right format
terraform validate                  # validate code is correct
terraform init                      # intialize terraform

terraform plan -out .terraform.plan # view resources to be created.
terraform apply ".terraform.plan"   # apply the terraform configuration
```
To replace an existing resource
```bash
terraform plan -replace=" **resource_name** " -out .terraform.plan
terraform apply ".terraform.plan"
```
## Terraform Output
The terraform code output displays several important infrastructure information needed by the operator/user.
* instance_ids.                # the instance_ids of all servers created on aws region
* public_ips                   # the public ips of all the servers
* check_ssh_script             # a status script that allow you check if servers are ready for ssh connection
* master_public_ip             # the elastic ip of the k8s master node
* worker_public_ips            # the elastic ip of the k8s worker nodes
* jenkins_public_ip            # the elastic ip of the jenkins node
* ansible_playbook_command     # command to run the playbook outside terraform (automation)
* cognito_user_pool_id         # openid user pool
* cognito_metadata_url         # openid metadata url
* cognito_client_id            # openid client_id
* cognito_client_secret        # openid client_secret
* jenkins_redirect_uri         # openid redirect_url

# Standby Terraform
For our recovery environment, a standby Terraform configuration is made available:
- It contains the original terraform configuration excluding the Jenkins server's provisioning and setup, and `AWS OpenID` and `Namedotcom` modules. 

They were determined as not needed for the standby environment. 
> NOTE: this standby environment is a Cold Backup, to be triggered by a lambda function created as part of the automated recovery process.

## How to RUN our Standby Terraform IaC
> If creating the Standby Environment MANUALLY

First, change Working directory. i.e.
```bash
cd standby_terraform
```
Second, run the terraform process.
```bash
terraform fmt                       # ensure code is in right format
terraform validate                  # validate code is correct
terraform init                      # intialize terraform

terraform plan -out .terraform.plan # view resources to be created.
terraform apply ".terraform.plan"   # apply the terraform configuration
```
To replace an existing resource
```bash
terraform plan -replace=" **resource_name** " -out .terraform.plan
terraform apply ".terraform.plan"
```