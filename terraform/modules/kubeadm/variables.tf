variable "remote_exec" {
  type = map(any)
  default = {
    ssh_user         = "ubuntu"
    private_key_path = "../../ansible/k8s-cluster.pem"
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


