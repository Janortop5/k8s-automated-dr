# variable "namecom_api_token" {
#   description = "Your Name.com API token (go to https://www.name.com/developers to generate one)"
#   type        = string
#   sensitive   = true
# }

# variable "have_you_added_your_ip_address_to_namecom_whitelist_true_or_false" {
#   description = "Have you added your IP address to Name.com's API access list? (https://www.name.com/account/api-access)"
#   type        = bool
# }

# variable "have_you_read_the_readme_true_or_false" {
#   description = "Have you read the README.md file in this directory?"
#   type        = bool
# }
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "remote_state_bucket_region" {
  description = "The AWS region where the S3 bucket for TF state is located"
  type        = string
  default     = "us-west-2"
}

variable "namecom_username" {
  description = "Your Name.com account username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_address" {
  description = "TF vault address"
  sensitive   = true
}

variable "vault_token" {
  description = "TF vault token"
  sensitive   = true
}

variable "ansible_vault_password" {
  description = "Ansible Vault password"
  sensitive   = true
}
