# Data source to read AWS credentials from Vault
data "vault_generic_secret" "aws_credentials" {
  path = var.vault_aws_path
}

# Data source to read other Velero secrets if needed
data "vault_generic_secret" "velero_secrets" {
  path = var.vault_velero_path
}

data "vault_generic_secret" "test" {
  path = "secret/test"
}

data "vault_generic_secret" "vault_token" {
  path = "secret/remote"
}

# Create the secrets YAML content
locals {
  secrets_content = {
    aws_access_key_id     = data.vault_generic_secret.aws_credentials.data["access_key"]
    aws_secret_access_key = data.vault_generic_secret.aws_credentials.data["secret_key"]
    velero_bucket_name    = data.vault_generic_secret.velero_secrets.data["bucket_name"]
    velero_region         = data.vault_generic_secret.velero_secrets.data["region"]
    remote_vault_token           = data.vault_generic_secret.vault_token.data["vault_token"]
    remote_vault_address         = data.vault_generic_secret.vault_token.data["vault_address"]
  }
}
