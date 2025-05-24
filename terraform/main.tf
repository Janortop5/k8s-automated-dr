module "ec2" {
  source = "./modules/ec2"
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
