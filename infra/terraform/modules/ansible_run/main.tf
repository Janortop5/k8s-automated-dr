terraform {
  required_version = ">= 1.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# just one host, so no for_each needed
resource "null_resource" "master-node" {
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      user        = var.remote_exec.ssh_user
      private_key = file(var.remote_exec.private_key_path)
      host        = var.master_ip
    }
  }
}

resource "null_resource" "worker-nodes" {
  for_each = var.worker_ips

  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]
    connection {
      type        = "ssh"
      user        = var.remote_exec.ssh_user
      private_key = file(var.remote_exec.private_key_path)
      host        = each.value
    }
  }
}

# also for jenkins, (just one host, so no for_each needed)
resource "null_resource" "jenkins-server" {
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]
    connection {
      type        = "ssh"
      user        = var.remote_exec.ssh_user
      private_key = file(var.remote_exec.private_key_path)
      host        = var.jenkins_ip
    }
  }
}

resource "null_resource" "ansible" {
  provisioner "local-exec" {
    command = <<-EOT
              ANSIBLE_CONFIG=${var.local_exec.ansible_config.filename} \
              ansible-playbook \
                -i ${var.local_exec.host_inventory.filename} \
                ${var.local_exec.ansible_playbook.kubeadm} \
                ${var.local_exec.ansible_playbook.jenkins} \
                --private-key ${var.remote_exec.private_key_path} \
                -u ${var.remote_exec.ssh_user} \
                -vvv
    EOT
  }
}