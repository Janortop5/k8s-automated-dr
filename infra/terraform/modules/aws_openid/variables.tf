variable "aws_region" {
  description = "AWS Region to deploy Cognito resources in"
  type        = string
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