# Terraform
This Terraform Configuration creates a Functional Kubeadm Kubernetes Environment and a Jenkins CI Server, both on AWS.

# Prerequisite
- Installation of **Docker** locally
- Installation of **Terraform** locally
- Instalation of **Ansibe** locally

## How to use our terraform IaC
#### First create Terraform vault.
- Add environment variables.
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
```
- Create terraform vault docker container.
```bash
docker run -dit --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=${vault_token}' --name 'tf_vault' -p 8200:8200 hashicorp/vault:latest
```
#### Test Vault Setup
- **Create test password.**
```bash
docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/test username='admin' password='1234'"
```
- **Test connection:** look for output -> `test_username = "admin"`
```
terraform init
terraform fmt
terraform plan

#Look for output -> test_username = "admin" -> connection success ✅
```
- **Create TF Vault Secrets**
```bash
docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/aws access_key='AKIA...' secret_key='your-secret-key'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/velero bucket_name='velero-demo-01' region='us-west-2'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/remote vault_address='http://127.0.0.1:8200' vault_token='${vault_token}'"

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/jenkins jenkins_username=${jenkins_username} jenkins_password=${jenkins_password}
EOF

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/git_credentials git_username=${git_username} git_password='\${git_password}'
EOF
```

#### Everything together
```bash
docker run -dit --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=0102911' --name 'tf_vault' -p 8200:8200 hashicorp/vault:latest

export TF_VAR_vault_address='http://127.0.0.1:8200'
export TF_VAR_ansible_vault_password='your-ansible-vault-token'
export TF_VAR_vault_token='your-tf-vault-token'
export TF_LOG=DEBUG
export vault_token='your-tf-vault-token'
export jenkins_username='your-jenkins-username'
export jenkins_password='your-jenkins-password'
export git_username='your-git-username'
export git_password='your-git-password'

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/test username='admin' password='1234'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/aws access_key='AKIA...' secret_key='your-secret-key'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/velero bucket_name='velero-demo-01' region='us-west-2'"

docker exec -it tf_vault sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && vault login ${vault_token} && vault kv put secret/remote vault_address='http://127.0.0.1:8200' vault_token='${vault_token}'"

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login ${vault_token}
vault kv put secret/jenkins jenkins_username=${jenkins_username} jenkins_password=${jenkins_password}
EOF

docker exec -i tf_vault sh << EOF
export VAULT_ADDR="http://127.0.0.1:8200"
vault login $vault_token
vault kv put secret/git_credentials git_username=$git_username git_password=$git_password
EOF
```
#### Run Terraform
- Format, Validate, Initialize and run the Terraform Configuration.
```bash
terraform fmt                       # ensure code is in right format
terraform validate                  # validate code is correct
terraform init                      # intialize terraform

terraform plan -out .terraform.plan # view resources to be created.
terraform apply ".terraform.plan"   # apply the terraform configuration
```
- **To replace an existing resource**
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