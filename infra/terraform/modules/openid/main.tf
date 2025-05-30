resource "aws_cognito_user_pool_client" "jenkins_client" {
  name                              = "jenkins-client"
  user_pool_id                      = aws_cognito_user_pool.jenkins_auth.id
  generate_secret                   = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                = ["code"]
  allowed_oauth_scopes               = ["openid", "profile", "email"]

  supported_identity_providers       = ["COGNITO"]


  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls
}