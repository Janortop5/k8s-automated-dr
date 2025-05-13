module "ec2" {
  source = "./modules/ec2"
}

module "kubeadm" {
  source = "./modules/kubeadm"
  host_inventory = {
    filename = "../ansible/hosts"
  }
  depends_on = [
    module.ec2
  ]
}