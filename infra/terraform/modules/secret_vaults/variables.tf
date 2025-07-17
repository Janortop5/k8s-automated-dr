
variable "vault_aws_path" {
  description = "Path to AWS credentials in Vault"
  default     = "secret/aws"
}

variable "vault_velero_path" {
  description = "Path to Velero credentials in Vault"
  default     = "secret/velero"
}

variable "ansible_vault_password" {
  description = "Ansible Vault password"
  sensitive   = true
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "local_exec" {
  type = map(any)
  default = {
    ansible_files = { secrets_tmp = "../ansible/group_vars/secrets.yml.tmp",
                      vault_pass = "../ansible/.vault_pass",
                      secrets_output = "../ansible/group_vars/secrets.yml",
                       },
  }
}