data "aws_caller_identity" "current" {
  provider = aws.remote_state
}

# Robust external data sources with proper error handling
data "external" "check_s3_bucket" {
  count = var.check_existing_resources ? 1 : 0
  program = ["bash", "-c", <<-EOT
    #!/bin/bash
    set -euo pipefail
    
    # Redirect all AWS CLI output to stderr to avoid JSON contamination
    if aws s3api head-bucket --bucket "${var.tf_state_bucket}" --region "${var.aws_region}" >/dev/null 2>&1; then
      echo '{"exists":"true"}' 
    else
      echo '{"exists":"false"}'
    fi
  EOT
  ]
}

data "external" "check_dynamodb_table" {
  count = var.check_existing_resources && var.aws_dynamodb_table_enabled ? 1 : 0
  program = ["bash", "-c", <<-EOT
    #!/bin/bash
    set -euo pipefail
    
    # Redirect all AWS CLI output to stderr to avoid JSON contamination
    if aws dynamodb describe-table --table-name "terraform-state-lock" --region "${var.aws_region}" >/dev/null 2>&1; then
      echo '{"exists":"true"}'
    else
      echo '{"exists":"false"}'
    fi
  EOT
  ]
}

data "external" "check_s3_bucket_policy" {
  count = var.check_existing_resources ? 1 : 0
  program = ["bash", "-c", <<-EOT
    #!/bin/bash
    set -euo pipefail
    
    # Redirect all AWS CLI output to stderr to avoid JSON contamination
    if aws s3api get-bucket-policy --bucket "${var.tf_state_bucket}" --region "${var.aws_region}" >/dev/null 2>&1; then
      echo '{"exists":"true"}'
    else
      echo '{"exists":"false"}'
    fi
  EOT
  ]
}

# Reference existing resources only when they exist
data "aws_s3_bucket" "existing_bucket" {
  provider = aws.remote_state
  count    = var.check_existing_resources && local.bucket_exists ? 1 : 0
  bucket   = var.tf_state_bucket
}

data "aws_dynamodb_table" "existing_table" {
  provider = aws.remote_state
  count    = var.check_existing_resources && var.aws_dynamodb_table_enabled && local.table_exists ? 1 : 0
  name     = "terraform-state-lock"
}

# IAM Policy Document for S3 bucket
data "aws_iam_policy_document" "tf_backend_bucket_policy" {
  provider = aws.remote_state
  
  # Allow authenticated access for the current account
  statement {
    sid    = "AllowAuthenticatedAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetBucketAcl",
      "s3:PutBucketAcl",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy"
    ]

    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*"
    ]

    principals {
      type        = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    actions = [
      "s3:*",
    ]

    resources = [
      "${local.bucket_arn}/*",
      local.bucket_arn
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"

      values = [
        false,
      ]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid    = "RequireEncryptedStorage"
    effect = "Deny"
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${local.bucket_arn}/*",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"

      values = [
        var.kms_master_key_id == "" ? "AES256" : "aws:kms"
      ]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

locals {
  # Safely extract existence information from external data sources
  bucket_exists = var.check_existing_resources ? (
    length(data.external.check_s3_bucket) > 0 ? 
    lookup(data.external.check_s3_bucket[0].result, "exists", "false") == "true" : false
  ) : false
  
  table_exists = var.check_existing_resources && var.aws_dynamodb_table_enabled ? (
    length(data.external.check_dynamodb_table) > 0 ? 
    lookup(data.external.check_dynamodb_table[0].result, "exists", "false") == "true" : false
  ) : false
  
  policy_exists = var.check_existing_resources ? (
    length(data.external.check_s3_bucket_policy) > 0 ? 
    lookup(data.external.check_s3_bucket_policy[0].result, "exists", "false") == "true" : false
  ) : false
  
  # Determine what resources to create
  create_bucket = var.check_existing_resources ? !local.bucket_exists : true
  create_table  = var.aws_dynamodb_table_enabled && (var.check_existing_resources ? !local.table_exists : true)
  create_policy = var.check_existing_resources ? !local.policy_exists : true
  
  # Resource references with fallbacks
  bucket_id = local.bucket_exists && length(data.aws_s3_bucket.existing_bucket) > 0 ? (
    data.aws_s3_bucket.existing_bucket[0].id
  ) : (
    local.create_bucket && length(aws_s3_bucket.tf_backend_bucket) > 0 ? 
    aws_s3_bucket.tf_backend_bucket[0].id : var.tf_state_bucket
  )
  
  bucket_arn = local.bucket_exists && length(data.aws_s3_bucket.existing_bucket) > 0 ? (
    data.aws_s3_bucket.existing_bucket[0].arn
  ) : (
    local.create_bucket && length(aws_s3_bucket.tf_backend_bucket) > 0 ? 
    aws_s3_bucket.tf_backend_bucket[0].arn : "arn:aws:s3:::${var.tf_state_bucket}"
  )
  
  # Table references
  table_name = local.table_exists && length(data.aws_dynamodb_table.existing_table) > 0 ? (
    data.aws_dynamodb_table.existing_table[0].name
  ) : (
    local.create_table && length(aws_dynamodb_table.basic-dynamodb-table) > 0 ? 
    aws_dynamodb_table.basic-dynamodb-table[0].name : "terraform-state-lock"
  )
  
  table_arn = local.table_exists && length(data.aws_dynamodb_table.existing_table) > 0 ? (
    data.aws_dynamodb_table.existing_table[0].arn
  ) : (
    local.create_table && length(aws_dynamodb_table.basic-dynamodb-table) > 0 ? 
    aws_dynamodb_table.basic-dynamodb-table[0].arn : 
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
  )
  
  # Policy JSON
  tf_backend_bucket_policy_json = data.aws_iam_policy_document.tf_backend_bucket_policy.json
  
  # Debug information (shows exactly what's happening)
  debug_info = {
    check_existing_resources    = var.check_existing_resources
    aws_dynamodb_table_enabled = var.aws_dynamodb_table_enabled
    external_bucket_result     = var.check_existing_resources && length(data.external.check_s3_bucket) > 0 ? data.external.check_s3_bucket[0].result : {}
    external_table_result      = var.check_existing_resources && var.aws_dynamodb_table_enabled && length(data.external.check_dynamodb_table) > 0 ? data.external.check_dynamodb_table[0].result : {}
    external_policy_result     = var.check_existing_resources && length(data.external.check_s3_bucket_policy) > 0 ? data.external.check_s3_bucket_policy[0].result : {}
    bucket_exists              = local.bucket_exists
    table_exists               = local.table_exists
    policy_exists              = local.policy_exists
    create_bucket              = local.create_bucket
    create_table               = local.create_table
    create_policy              = local.create_policy
    bucket_id                  = local.bucket_id
    table_name                 = local.table_name
  }
}