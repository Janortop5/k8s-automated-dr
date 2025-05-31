# 4) Outputs to consume in your Jenkins init.groovy
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.jenkins.id
}

output "cognito_metadata_url" {
  description = "OpenID Connect metadata endpoint for Cognito"
  value       = "https://${var.aws_cognito_domain}.auth.${var.aws_region}.amazoncognito.com/.well-known/openid-configuration"
}

output "cognito_client_id" {
  description = "OIDC client ID for Jenkins"
  value       = aws_cognito_user_pool_client.jenkins.id
}

output "cognito_client_secret" {
  description = "OIDC client secret for Jenkins"
  value       = aws_cognito_user_pool_client.jenkins.client_secret
}

output "jenkins_redirect_uri" {
  value       = var.jenkins_redirect_uri[0]
  description = "The redirect URI for Jenkins OIDC authentication"
}