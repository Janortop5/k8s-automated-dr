# root/providers.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
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
  backend "s3" {
   region         = "us-west-2"
   bucket         = "k8s-automated-dr"
   key            = "standby/terraform.tfstate"
   dynamodb_table = "terraform-state-lock"
   encrypt        = true
 }
}

provider "aws" {
  region = var.aws_region
}
