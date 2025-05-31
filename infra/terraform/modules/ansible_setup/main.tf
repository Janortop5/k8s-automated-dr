terraform {
  required_version = ">= 1.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
resource "local_file" "host_inventory" {
  filename = var.host_inventory.filename

  content = <<-EOF
[master-node]
${var.master_ip}

[worker-node]
%{ for ip in values(var.worker_ips) ~}
${ip}
%{ endfor ~}

[jenkins-server]
${var.jenkins_ip}
  EOF
}

resource "local_file" "master-node-vars" {
  filename = "${var.local_exec.ansible_vars.filename}"

  content = <<-EOF
  master_public_ip: "${var.master_ip}"
  EOF
}
