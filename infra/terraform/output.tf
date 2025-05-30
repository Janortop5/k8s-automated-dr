output "instance_ids_1_2" {
  value = module.ec2.instance_ids_1_2
}

output "public_ips_1_2" {
  value = module.ec2.public_ips_1_2
}

output "instance_ids_3_4" {
  value = module.ec2.instance_ids_3_4
}

output "public_ips_3_4" {
  value = module.ec2.public_ips_3_4
}

output "check_ssh_script" {
  value = module.ansible_setup.check_ssh_script
}

output "ansible_playbook_command" {
  value = module.ansible_setup.ansible_playbook_command
}