# root/providers.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    namedotcom = {
      source  = "lexfrei/namedotcom"
      version = "~> 1.1.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# provider "namedotcom" {
#   token = var.namecom_api_token # Pass as enviroment variable TF_VAR_namecom_api_token
#   username = var.namecom_username # Pass as enviroment variable TF_VAR_namecom_username
# }

