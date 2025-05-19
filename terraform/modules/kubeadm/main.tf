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

  # ensure inventory isn’t written until the IPs exist
  depends_on = [
    null_resource.master-node,
    null_resource.worker-node,
    null_resource.jenkins-server,
  ]
}

resource "local_file" "master-node-vars" {
  filename = "${var.local_exec.ansible_vars.filename}"

  content = <<-EOF
  master_public_ip: "${var.master_ip}"
  EOF
}

# just one host, so no for_each needed
resource "null_resource" "master-node" {
  provisioner "remote-exec" {
    inline = [
      "echo 'SSH is ready'",
      "which python >/dev/null 2>&1 || sudo apt-get update -y",
      "sudo apt-get install -y python3 python3-apt",
      "sudo ln -sf /usr/bin/python3 /usr/bin/python"
    ]

    connection {
      type        = "ssh"
      user        = var.remote_exec.ssh_user
      private_key = file(var.remote_exec.private_key_path)  # it is relative to root module
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
      private_key = file(var.remote_exec.private_key_path)  # it is relative to root module
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
      private_key = file(var.remote_exec.private_key_path)  # it is relative to root module
      host        = var.jenkins_ip
    }
  }
}

resource "null_resource" "ansible" {
  # this map must change each plan → Terraform will destroy & recreate this resource
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
              export ANSIBLE_CONFIG=${var.local_exec.ansible_config.filename}
              ansible-playbook -i ${var.local_exec.host_inventory.filename} \
              ${var.local_exec.ansible_playbook.filename} -vvv
    EOT
  }
}
