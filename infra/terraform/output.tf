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

output "cognito_user_pool_id" {
  value = module.aws_openid.cognito_user_pool_id
}

output "cognito_metadata_url" {
  value = module.aws_openid.cognito_metadata_url
}

output "cognito_client_id" {
  value = module.aws_openid.cognito_client_id
}

output "cognito_client_secret" {
  value     = module.aws_openid.cognito_client_secret
  sensitive = true
}

output "jenkins_redirect_uri" {
  value = module.aws_openid.jenkins_redirect_uri
}

output "master_public_ip" {
  value = module.ec2.master_public_ip
}

output "worker_public_ips" {
  value = module.ec2.worker_public_ips
}

output "jenkins_public_ip" {
  value = module.ec2.jenkins_public_ip
}

output "master_private_ip" {
  value = module.ec2.master_private_ip
}

output "jenkins_private_ip" {
  value = module.ec2.jenkins_private_ip
}

output "vault_secrets_created" {
  value = module.secret_vaults.vault_secrets_created
}

output "test_username" {
  value     = module.secret_vaults.test_username
  sensitive = false
}