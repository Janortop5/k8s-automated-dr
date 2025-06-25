variable "remote_exec" {
  type = map(any)
  default = {
    ssh_user         = "ubuntu"
    private_key_path = "../k8s-cluster.pem"  # file() used to read the private key file, it is relative to root module
  }
}

variable "local_exec" {
  type = map(any)
  default = {
    host_inventory = { filename = "../ansible/hosts" },
    ansible_config = { filename = "../ansible/ansible.cfg" },
    ansible_playbook = { playbook = "../ansible/playbook.yml", kubeadm = "../ansible/kubeadm.yml", jenkins = "../ansible/jenkins.yml" },
    ansible_vars = { master-node = "../ansible/host_vars/master-node.yml", 
                    jenkins-node = "../ansible/group_vars/all.yml" },
  }
}

variable "master_ip" {
  type = string
}

variable "worker_ips" {
  type = map(string)
}

variable "jenkins_ip" {
  type = string
}

variable "host_inventory" {
  type = object({
    filename = string
  })
}


