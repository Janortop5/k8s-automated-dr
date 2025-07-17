# Output for verification
output "vault_secrets_created" {
  value = "Ansible Vault secrets file created at: ${var.local_exec.ansible_files.secrets_output}"
}

output "test_username" {
  value = nonsensitive(data.vault_generic_secret.test.data["username"])
}