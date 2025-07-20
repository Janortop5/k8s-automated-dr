data "aws_caller_identity" "current" {
  provider = aws.remote_state
}

# Data sources to check if resources exist
data "aws_s3_bucket" "existing_bucket" {
  provider = aws.remote_state
  count    = var.check_existing_resources ? 1 : 0
  bucket   = var.tf_state_bucket
  
  # This will fail gracefully if bucket doesn't exist
  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "Bucket does not exist"
    }
  }
}

data "aws_dynamodb_table" "existing_table" {
  provider = aws.remote_state
  count    = var.check_existing_resources && var.aws_dynamodb_table_enabled ? 1 : 0
  name     = "terraform-state-lock"
  
  # This will fail gracefully if table doesn't exist
  lifecycle {
    postcondition {
      condition     = self.name != ""
      error_message = "DynamoDB table does not exist"
    }
  }
}

# Check if bucket policy already exists
data "aws_s3_bucket_policy" "existing_policy" {
  provider = aws.remote_state
  count    = var.check_existing_resources ? 1 : 0
  bucket   = var.tf_state_bucket
  
  lifecycle {
    postcondition {
      condition     = self.policy != ""
      error_message = "Bucket policy does not exist"
    }
  }
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
  # Determine if resources exist
  bucket_exists = var.check_existing_resources ? length(data.aws_s3_bucket.existing_bucket) > 0 : false
  table_exists  = var.check_existing_resources && var.aws_dynamodb_table_enabled ? length(data.aws_dynamodb_table.existing_table) > 0 : false
  policy_exists = var.check_existing_resources ? length(data.aws_s3_bucket_policy.existing_policy) > 0 : false
  
  # Determine what to create
  create_bucket = !local.bucket_exists
  create_table  = var.aws_dynamodb_table_enabled && !local.table_exists
  create_policy = !local.policy_exists
  
  # Bucket ID reference (existing or new)
  bucket_id = local.bucket_exists ? data.aws_s3_bucket.existing_bucket[0].id : aws_s3_bucket.tf_backend_bucket[0].id
  
  # Policy JSON
  tf_backend_bucket_policy_json = data.aws_iam_policy_document.tf_backend_bucket_policy.json
}