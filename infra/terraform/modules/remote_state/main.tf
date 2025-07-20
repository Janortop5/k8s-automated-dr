resource "aws_s3_bucket" "tf_backend_bucket" {
  provider = aws.remote_state
  bucket = var.tf_state_bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "tf_backend_bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_acl" "tf_backend_bucket_acl" {
  provider = aws.remote_state
  bucket = aws_s3_bucket.tf_backend_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.tf_backend_bucket_ownership]
}


resource "aws_s3_bucket_ownership_controls" "tf_backend_bucket_ownership" {
  provider = aws.remote_state
  bucket = aws_s3_bucket.tf_backend_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "tf_backend_bucket_versioning" {
  provider = aws.remote_state
  bucket = aws_s3_bucket.tf_backend_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_backend_bucket_encryption" {
  provider = aws.remote_state
  bucket = aws_s3_bucket.tf_backend_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_master_key_id
      sse_algorithm     = var.kms_master_key_id == "" ? "AES256" : "aws:kms"
    }
  }
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  provider = aws.remote_state
  count          = var.aws_dynamodb_table_enabled ? 1 : 0
  name           = "terraform-state-lock"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "dynamodb-table-1"
    Environment = "production"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "tf_backend_bucket_policy" {
  provider = aws.remote_state
  bucket   = aws_s3_bucket.tf_backend_bucket.id
  policy   = local.tf_backend_bucket_policy_json
}