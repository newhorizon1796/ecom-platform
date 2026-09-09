terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state for the bootstrap only — everything else in this repo
  # uses the S3 backend this creates. Chicken-and-egg problem, solved
  # by keeping this one module's state on disk.
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  # Bucket names are globally unique — suffix with account ID to guarantee that.
  bucket = "ecom-platform-tfstate-${data.aws_caller_identity.current.account_id}"

  # Ephemeral project, but state must survive terraform destroy runs against
  # the *other* modules — force_destroy stays false so this bucket is never
  # accidentally emptied by an unrelated apply/destroy elsewhere.
  force_destroy = false

  tags = {
    Project   = "ecom-platform"
    ManagedBy = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tflock" {
  name         = "ecom-platform-tflock"
  billing_mode = "PAY_PER_REQUEST" # no idle cost — pay only for the few requests a state lock makes
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project   = "ecom-platform"
    ManagedBy = "terraform-bootstrap"
  }
}
