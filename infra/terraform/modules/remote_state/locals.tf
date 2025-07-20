data "aws_caller_identity" "current" {
  provider = aws.remote_state
}

# External data sources to check if resources exist
data "external" "check_s3_bucket" {
  count = var.check_existing_resources ? 1 : 0
  program = ["bash", "-c", <<-EOT
    if aws s3api head-bucket --bucket "${var.tf_state_bucket}" 2>/dev/null; then
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
    if aws dynamodb describe-table --table-name "terraform-state-lock" 2>/dev/null; then
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
    if aws s3api get-bucket-policy --bucket "${var.tf_state_bucket}" 2>/dev/null; then
      echo '{"exists":"true"}'
    else
      echo '{"exists":"false"}'
    fi
  EOT
  ]
}

# Only fetch existing resources if they actually exist
data "aws_s3_bucket" "existing_bucket" {
  provider = aws.remote_state
  count    = var.check_existing_resources && local.bucket_exists_check ? 1 : 0
  bucket   = var.tf_state_bucket
}

data "aws_dynamodb_table" "existing_table" {
  provider = aws.remote_state
  count    = var.check_existing_resources && var.aws_dynamodb_table_enabled && local.table_exists_check ? 1 : 0
  name     = "terraform-state-lock"
}

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
      local.bucket_exists ? data.aws_s3_bucket.existing_bucket[0].arn : aws_s3_bucket.tf_backend_bucket[0].arn,
      "${local.bucket_exists ? data.aws_s3_bucket.existing_bucket[0].arn : aws_s3_bucket.tf_backend_bucket[0].arn}/*"
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
      "${local.bucket_exists ? data.aws_s3_bucket.existing_bucket[0].arn : aws_s3_bucket.tf_backend_bucket[0].arn}/*",
      local.bucket_exists ? data.aws_s3_bucket.existing_bucket[0].arn : aws_s3_bucket.tf_backend_bucket[0].arn
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
      "${local.bucket_exists ? data.aws_s3_bucket.existing_bucket[0].arn : aws_s3_bucket.tf_backend_bucket[0].arn}/*",
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
  # Check existence from external data sources
  bucket_exists_check = var.check_existing_resources ? data.external.check_s3_bucket[0].result.exists == "true" : false
  table_exists_check  = var.check_existing_resources && var.aws_dynamodb_table_enabled ? data.external.check_dynamodb_table[0].result.exists == "true" : false
  policy_exists_check = var.check_existing_resources ? data.external.check_s3_bucket_policy[0].result.exists == "true" : false
  
  # Determine if resources exist (for referencing)
  bucket_exists = local.bucket_exists_check
  table_exists  = local.table_exists_check
  policy_exists = local.policy_exists_check
  
  # Determine what to create
  create_bucket = !local.bucket_exists
  create_table  = var.aws_dynamodb_table_enabled && !local.table_exists
  create_policy = !local.policy_exists
  
  # Bucket ID reference (existing or new)
  bucket_id = local.bucket_exists ? data.aws_s3_bucket.existing_bucket[0].id : aws_s3_bucket.tf_backend_bucket[0].id
  
  # Policy JSON
  tf_backend_bucket_policy_json = data.aws_iam_policy_document.tf_backend_bucket_policy.json
}