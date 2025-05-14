resource "local_file" "host_inventory" {
  filename = var.host_inventory.filename
  content  = <<EOF
[master-node]
${var.master_ip}

[worker-node]
${join("\n", values(var.worker_ips))}

[jenkins-server]
${var.jenkins_ip}
EOF
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

resource "null_resource" "worker-node" {
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
              export ANSIBLE_CONFIG=./ansible/ansible.cfg
              ansible-playbook ./ansible/playbook.yml
    EOT
  }
}
