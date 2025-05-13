resource "local_file" "host_inventory" {
  filename = var.host_inventory.filename
  content  = "[master-node]\n${aws_instance.ec2_instance-1-2[var.ec2_instance_az1.k8s-cluster-server-1.key].public_ip}\n\n[worker-node]\n${aws_instance.ec2_instance-1-2[var.ec2_instance_az1.k8s-cluster-server-2.key].public_ip}\n${aws_instance.ec2_instance-1-2[var.ec2_instance_az1.k8s-cluster-server-2.key].public_ip}\n${aws_instance.ec2_instance-3-4[var.ec2_instance_az2.k8s-cluster-server-3.key].public_ip}\n\n[jenkins-server]\n${aws_instance.ec2_instance-3-4[var.ec2_instance_az2.jenkins-ci-server.key].public_ip}"
}

resource "null_resource" "ansible-1-2" {
  for_each = module.ec2.var.ec2_instance_az1
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      user        = var.remote_exec.ssh_user
      private_key = file(var.remote_exec.private_key_path)
      host        = aws_instance.ec2_instance-1-2[each.key].public_ip
    }
  }
}

resource "null_resource" "ansible-3-4" {
  for_each = module.ec2.var.ec2_instance_az2
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      user        = var.remote_exec.ssh_user
      private_key = file(var.remote_exec.private_key_path)
      host        = aws_instance.ec2_instance-3-4[each.key].public_ip
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
