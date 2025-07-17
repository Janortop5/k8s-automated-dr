# Generate Ansible Vault password file
resource "local_file" "vault_pass" {
  content         = var.ansible_vault_password
  filename        = "${var.local_exec.ansible_files.vault_pass}"
  file_permission = "0600"
}

# Generate the secrets file for Ansible Vault encryption
resource "local_file" "secrets_yaml" {
  content = templatefile("${path.module}/templates/secrets.yml.tpl", local.secrets_content)
  filename = "${var.local_exec.ansible_files.secrets_tmp}"

  provisioner "local-exec" {
    command = <<-EOT
      ansible-vault encrypt ${var.local_exec.ansible_files.secrets_tmp} \
        --vault-password-file ${var.local_exec.ansible_files.vault_pass} \
        --output ${var.local_exec.ansible_files.secrets_output}

      # Also update the existing group_vars/secrets.yml if it exists
      if [ -f ${var.local_exec.ansible_files.secrets_output} ]; then
        ansible-vault encrypt ${var.local_exec.ansible_files.secrets_tmp} \
          --vault-password-file ${var.local_exec.ansible_files.vault_pass} \
          --output ${var.local_exec.ansible_files.secrets_output}
      fi

      rm ${var.local_exec.ansible_files.secrets_tmp}
    EOT
  }
}