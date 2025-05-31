terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1) Create a Cognito User Pool
resource "aws_cognito_user_pool" "jenkins" {
  name = "jenkins-auth-pool"

  # (optional) email verification, password policy, etc.
  auto_verified_attributes = ["email"]
  alias_attributes         = ["email"]
}

# 2) Create an App Client with secret, enabling OIDC Authorization Code grant
resource "aws_cognito_user_pool_client" "jenkins" {
  name                              = "jenkins-client"
  user_pool_id                      = aws_cognito_user_pool.jenkins.id
  generate_secret                   = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                = ["code"]
  allowed_oauth_scopes               = ["openid", "profile", "email"]

  supported_identity_providers       = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH"]


  callback_urls = var.jenkins_redirect_uri
  logout_urls   = var.logout_urls
}

# 3) Create a Hosted Domain so Cognito exposes a .well-known endpoint
resource "aws_cognito_user_pool_domain" "jenkins" {
  domain      = var.aws_cognito_domain
  user_pool_id = aws_cognito_user_pool.jenkins.id
}