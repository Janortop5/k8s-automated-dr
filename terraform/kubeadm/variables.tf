variable "remote_exec" {
  type = map(any)
  default = {
    ssh_user         = "ubuntu"
    private_key_path = "../../ansible/k8s-cluster.pem"
  }
}

variable "host_inventory" {
  type = map(any)
  default = {
    filename = "../../ansible/hosts"
  }
}

