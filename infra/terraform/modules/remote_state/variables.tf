variable "kms_master_key_id" {
  default = ""
}

variable "read_capacity" {
  type    = number
  default = 1
}

variable "write_capacity" {
  type    = number
  default = 1
}

variable "aws_dynamodb_table_enabled" {
  type    = bool
  default = true
}

# THESE VARIABLES BELOW ARE NOT USED IN THIS MODULE, BUT ARE USED IN THE STANDBY_TERRAFORM 'variables.tf' FILE
# THE VARIABLES ARE SPECIFIED HERE SO THAT THEY CAN BE REFERENCED IN THE ROOT MODULE'S 'main.tf' FILE FOR THE PRIMARY_TERRAFORM
# THE VARIABLES ARE REFERENCED IN THE ROOT'S 'main.tf' FILE TO AID THEIR VISIBILTY, BUT ARE ONLY USED IN THE `standby_terraform` MODULE
variable "tf_state_bucket" {
  description = "The S3 bucket to store the Terraform state file"
  type        = string
}

variable "tf_state_key" {
  description = "The key for the Terraform state file in S3"
  type        = string
}

variable "tf_state_table" {
  description = "The DynamoDB table for Terraform state locking"
  type        = string
}

variable "check_existing_resources" {
  description = "Whether to check if resources already exist before creating them"
  type        = bool
  default     = true
}