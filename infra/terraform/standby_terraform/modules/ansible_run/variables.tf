variable "remote_exec" {
  type = map(any)
  default = {
    ssh_user         = "ubuntu"
    private_key_path = "./standby-k8s-cluster.pem"  # file() used to read the private key file, it is relative to root module
  }
}

variable "local_exec" {
  type = map(any)
  default = {
    host_inventory = { filename = "../../ansible/standby-hosts" },
    ansible_config = { filename = "../../ansible/ansible.cfg" },
    ansible_playbook = { kubeadm = "../../ansible/kubeadm.yml", velero = "../../ansible/tasks/restore_backup.yml" },
    ansible_vars = { filename = "../../ansible/host_vars/master-node.yml" },
  }
}

variable "master_ip" {
  type = string
}

variable "worker_ips" {
  type = map(string)
}

variable "host_inventory" {
  type = object({
    filename = string
  })
}
