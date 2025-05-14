module "ec2" {
  source = "./modules/ec2"
}

module "kubeadm" {
  source = "./modules/kubeadm"
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

