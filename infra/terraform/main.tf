module "ec2" {
  source = "./modules/ec2"
}

module "name_dot_com" {
  source = "./modules/name_dot_com"

  # Pass in the variables for the domain setup
  namecom_api_token = var.namecom_api_token # Pass as enviroment variable TF_VAR_namecom_api_token
  namecom_username = "janortop5" 
  domain_name = "eaaladejana.xyz"
  jenkins_record_name = "jenkins"
  record_ip = module.ec2.jenkins_public_ip
}

module "ansible_setup" {
  source = "./modules/ansible_setup"
  host_inventory = {
    filename = "../ansible/hosts"
  }

  # Pass in the lists/maps of IPs you need
  master_ip      = module.ec2.master_public_ip
  worker_ips      = module.ec2.worker_public_ips
  jenkins_ip      = module.ec2.jenkins_public_ip

  depends_on = [
    module.ec2
  ]
}

# inspect module "ansible_run" to select the ansible playbooks you want to run {kubeadm, jenkins, playbook}
module "ansible_run" {
  source = "./modules/ansible_run"
  host_inventory = {
    filename = "../ansible/hosts"
  }

  # Pass in the lists/maps of IPs you need
  master_ip      = module.ec2.master_public_ip
  worker_ips      = module.ec2.worker_public_ips
  jenkins_ip      = module.ec2.jenkins_public_ip
  
  depends_on = [
    module.ansible_setup
  ]
}

# This module sets up AWS OpenID Connect integration for Jenkins
module "aws_openid" {
  source = "./modules/aws_openid"

  # Pass in variables for the jenkins openid setup
  jenkins_base_url = "https://jenkins.eaaladejana.xyz"
  jenkins_redirect_uri = [ "https://jenkins.eaaladejana.xyz/securityRealm/finishLogin" ]
  logout_urls = [ "https://jenkins.eaaladejana.xyz/logout" ]
  aws_cognito_domain = "k8s-automated-dr"
}