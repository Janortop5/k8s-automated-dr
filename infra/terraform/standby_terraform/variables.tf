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
  default     = "us-west-1"
}

variable "namecom_username" {
  description = "Your Name.com account username"
  type        = string
  sensitive   = true
  default     = ""
}
