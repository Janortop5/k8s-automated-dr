# Terraform
*Fun project to develop, learn and build.

## How to use k8s_lstm_pipeline terraform IaC
```bash
terraform fmt                       # ensure code is in right format
terraform validate                  # validate code is correct
terraform init                      # intialize terraform

terraform plan -out .terraform.plan # view resources to be created.
terraform apply ".terraform.plan"   # apply the terraform configuration
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

