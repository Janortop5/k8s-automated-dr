variable "aws_region" {
  description = "AWS Region to deploy Cognito resources in"
  type        = string
  default     = "us-east-1"
}

variable "cognito_domain" {
  description = "Unique prefix for the Cognito user‐pool domain (must be globally unique)"
  type        = string
  default     = "jenkins-auth"
}

variable "jenkins_base_url" {
  description = "Base URL of your Jenkins server (no trailing slash)"
  type        = string
  default     = "https://jenkins.example.com"
}

variable "callback_urls" {
  description = "OAuth2 callback URLs for the Cognito App Client"
  type        = list(string)
  default     = [
    "${var.jenkins_base_url}/securityRealm/finishLogin"
  ]
}

variable "logout_urls" {
  description = "Allowed logout URLs for the Cognito App Client"
  type        = list(string)
  default     = [
    "${var.jenkins_base_url}/"
  ]
}