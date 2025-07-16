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
  default     = "us-west-2"
}

variable "namecom_username" {
  description = "Your Name.com account username"
  type        = string
  sensitive   = true
  default     = ""
}


variable "aws_access_key" {
  description = "AWS access key"
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  sensitive   = true
}

variable "backup_bucket_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "backup_bucket" {
  description = "S3 bucket for Velero"
}