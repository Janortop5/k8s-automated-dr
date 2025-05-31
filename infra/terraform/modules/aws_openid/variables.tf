variable "aws_region" {
  description = "AWS Region to deploy Cognito resources in"
  type        = string
  # Defaulting to 'us-east-1' as it is widely used and offers lower latency for most users.
  default     = "us-east-1"
}

variable "aws_cognito_domain" {
  description = "Unique prefix for the Cognito user-pool domain (must be globally unique)"
  type        = string
}

variable "jenkins_base_url" {
  description = "Base URL of your Jenkins server (no trailing slash)"
  type        = string
}

variable "jenkins_redirect_uri" {
  description = "OAuth2 callback URLs for the Cognito App Client"
  type        = list(string)
}

variable "logout_urls" {
  description = "Allowed logout URLs for the Cognito App Client"
  type        = list(string)
}