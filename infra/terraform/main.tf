# module "name_dot_com" {
#   source = "./modules/name_dot_com"

#   # Pass in the variables for the domain setup
#   domain_name = "eaaladejana.xyz"
#   jenkins_record_name = "jenkins"
#   record_ip = module.ec2.jenkins_public_ip
# }

module "ec2" {
  source = "./modules/ec2"
}

# THIS MODULE MUST RUN BEFORE THE STANDBY_TERRAFORM MODULE (INITIALIZES ITS REMOTE BACKEND)
module "remote_state" {
  source = "./modules/remote_state"

  # THE VALUES BELOW TO BE SPECIFIED IN THE VARIABLE BLOCKS OF THE STANDBY CLUSTER'S 'variables.tf' FILE
  # THE RESOURCES FOR REMOTE TF STATE (BUCKET AND DYNAMODB TABLE) MUST BE CREATED IN THE SAME REGION AS THE STANDBY MODULE i.e.
  # standby_terraform/providers.tf: 'var.aws_region = "us-west-2' -> 'var.bucket_region = "us-west-2"'
  tf_state_bucket = "k8s-automated-dr"
  tf_state_key    = "standby/terraform.tfstate"
  tf_state_table  = "terraform-state-lock"

  providers = {
    aws.remote_state = aws.remote_state # -> THIS REGION MUST MATCH THE STANDBY TERRAFORM MODULE REGION
  }
}

module "secret_vaults" {
  source                 = "./modules/secret_vaults"
  ansible_vault_password = var.ansible_vault_password
}

module "ansible_setup" {
  source = "./modules/ansible_setup"
  host_inventory = {
    filename = "../ansible/hosts"
  }

  # Pass in the lists/maps of IPs you need
  master_ip          = module.ec2.master_public_ip
  worker_ips         = module.ec2.worker_public_ips
  jenkins_ip         = module.ec2.jenkins_public_ip
  jenkins_private_ip = module.ec2.jenkins_private_ip
  master_private_ip  = module.ec2.master_private_ip

  depends_on = [
    module.ec2,
    module.secret_vaults
  ]
}

# inspect module "ansible_run" to select the ansible playbooks you want to run {kubeadm, jenkins, playbook}
module "ansible_run" {
  source = "./modules/ansible_run"
  host_inventory = {
    filename = "../ansible/hosts"
  }

  # Pass in the lists/maps of IPs you need
  master_ip  = module.ec2.master_public_ip
  worker_ips = module.ec2.worker_public_ips
  jenkins_ip = module.ec2.jenkins_public_ip

  depends_on = [
    module.ansible_setup
  ]
}

# This module sets up AWS OpenID Connect integration for Jenkins
module "aws_openid" {
  source = "./modules/aws_openid"

  # Pass in variables for the jenkins openid setup
  jenkins_base_url     = "https://jenkins.${module.ec2.jenkins_public_ip}.nip.io"
  jenkins_redirect_uri = ["https://jenkins.${module.ec2.jenkins_public_ip}.nip.io/securityRealm/finishLogin"]
  logout_urls          = ["https://jenkins.${module.ec2.jenkins_public_ip}.nip.io/logout"]
  aws_cognito_domain   = "k8s-automated-dr"
  aws_region           = var.aws_region
}