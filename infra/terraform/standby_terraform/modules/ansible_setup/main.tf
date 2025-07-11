resource "local_file" "host_inventory" {
  filename = var.host_inventory.filename

  content = <<-EOF
[master-node]
${var.master_ip}

[worker-node]
%{ for ip in values(var.worker_ips) ~}
${ip}
%{ endfor ~}

  EOF
}

resource "local_file" "master-node-vars" {
  filename = "${var.local_exec.ansible_vars.master-node}"

  content = <<-EOF
  master_public_ip: "${var.master_ip}"
  master_private_ip: "${var.master_private_ip}"
  EOF
}
