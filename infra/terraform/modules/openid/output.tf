output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.jenkins_auth.id
}

output "openid_issuer" {
  value = "https://${aws_cognito_user_pool_domain.jenkins_domain.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "openid_configuration_url" {
  value = "${output.openid_issuer}/.well-known/openid-configuration"
}

output "client_id" {
  value = aws_cognito_user_pool_client.jenkins_client.id
}

output "client_secret" {
  value     = aws_cognito_user_pool_client.jenkins_client.client_secret
  sensitive = true
}