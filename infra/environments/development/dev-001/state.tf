terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
# For Remote State with S3 and DynamoDB Locking, uncomment below and comment above
# terraform {
#   backend "s3" {
#     bucket         = "dev-001-state"
#     key            = "oss-iac-dev/terraform.tfstate"
#     region         = "us-west-2"
#     encrypt        = true
#     kms_key_id     = "alias/dev-001/terraform-bucket-key"
#     dynamodb_table = "dev-001-terraform-state"
#   }
# }

resource "aws_kms_key" "terraform-bucket-key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    environment = var.environment
  }
}

resource "aws_kms_alias" "key-alias" {
  name          = "alias/${var.environment}/terraform-bucket-key"
  target_key_id = aws_kms_key.terraform-bucket-key.key_id
}

resource "aws_s3_bucket" "terraform-state" {
  bucket = "${var.environment}-state"

  tags = {
    environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform-bucket-key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.terraform-state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform-state" {
  name           = "${var.environment}-terraform-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
