variable "namecom_api_token" {
  description = "Your Name.com API token (go to https://www.name.com/developers to generate one)"
  type        = string
  sensitive   = true
}

variable "have_you_added_your_ip_address_to_namecom_whitelist?" {
  description = "Have you added your IP address to Name.com's API access list? (https://www.name.com/account/api-access)"
  type        = bool
  default     = false
}

variable "have_you_read_the_readme?" {
  description = "Have you read the README.md file in this directory?"
  type        = bool
  default     = false
}