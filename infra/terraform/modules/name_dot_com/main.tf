terraform {
  required_providers {
    namedotcom = {
      source  = "lexfrei/namedotcom"
      version = "~> 1.1.6"
    }
  }
}

provider "namedotcom" {
  username = var.namecom_username      # your Name.com account username
  token    = var.namecom_api_token     # your Name.com API token
}

resource "namedotcom_record" "record" {
  domain_name = var.domain_name
  host        = var.jenkins_record_name               # e.g. "jenkins" → creates jenkins.example.com; ensure var.record_name is defined and matches the intended subdomain
  record_type = "A"
  answer      = var.record_ip
}