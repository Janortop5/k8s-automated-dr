data "aws_caller_identity" "current" {
  provider = aws.remote_state
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
      "${aws_s3_bucket.tf_backend_bucket.arn}",
      "${aws_s3_bucket.tf_backend_bucket.arn}/*"
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
      "${aws_s3_bucket.tf_backend_bucket.arn}/*",
      "${aws_s3_bucket.tf_backend_bucket.arn}"
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
      "${aws_s3_bucket.tf_backend_bucket.arn}/*",
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
  tf_backend_bucket_policy_json = data.aws_iam_policy_document.tf_backend_bucket_policy.json
}