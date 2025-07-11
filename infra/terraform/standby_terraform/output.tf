output "instance_ids" {
  value = module.ec2.instance_ids
}

output "public_ips" {
  value = module.ec2.public_ips
}

output "check_ssh_script" {
  value = module.ansible_setup.check_ssh_script
}

output "ansible_playbook_command" {
  value = module.ansible_setup.ansible_playbook_command
}

output "master_public_ip" {
  value = module.ec2.master_public_ip
}

output "worker_public_ips" {
  value = module.ec2.worker_public_ips
}

output "master_private_ip" {
  value = module.ec2.master_private_ip
}
