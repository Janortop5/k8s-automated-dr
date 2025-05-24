# 1) Emit a simple bash script that waits for SSH on each master node
output "check_ssh_script" {
  description = "A bash script to wait for SSH on each master node and then show you how to connect"
  value = <<EOF
#!/usr/bin/env bash
# Save this as check_ssh.sh and run: bash check_ssh.sh

USER="${var.remote_exec.ssh_user}"
KEY="${var.remote_exec.private_key_path}"

for HOST in ${var.master_ip} ${join(" ", values(var.worker_ips))} ${var.jenkins_ip}; do
  echo "⏳ Waiting for SSH on $HOST..."
  until nc -z -w 5 "$HOST" 22; do
    sleep 2
  done
  echo "✅ SSH is ready on $HOST"
  echo "Connect with:"
  echo "  ssh -i $KEY -o StrictHostKeyChecking=no $USER@$HOST"
done
EOF
}

# 2) Emit the Ansbile playbook invocation you’d use once SSH is up
output "ansible_playbook_command" {
  description = "Command to run your Ansible playbook against the new hosts"
  value       = <<EOF
ANSIBLE_CONFIG=${var.local_exec.ansible_config.filename} \
ansible-playbook \
  -i ${var.local_exec.host_inventory.filename} \
  ${var.local_exec.ansible_playbook.playbook} \   # Main playbook file, comment out or uncomment playbooks to run as needed in this file
  --private-key ${var.remote_exec.private_key_path} \
  -u ${var.remote_exec.ssh_user} \
  -vvv
EOF
}


