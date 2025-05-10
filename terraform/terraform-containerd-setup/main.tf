resource "null_resource" "containerd_setup" {
  # This makes the resource run only when the trigger changes
  triggers = {
    script_hash = sha256(file("${path.module}/containerd_setup.sh"))
  }

  # For remote execution on a provisioned VM
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.host_ip
    private_key = file(var.private_key_path)
  }

  # Upload the script
  provisioner "file" {
    source      = "${path.module}/containerd_setup.sh"
    destination = "/tmp/containerd_setup.sh"
  }

  # Execute the script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/containerd_setup.sh",
      "/tmp/containerd_setup.sh"
    ]
  }
  }