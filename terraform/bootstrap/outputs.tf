output "tfstate_bucket" {
  value       = aws_s3_bucket.tfstate.id
  description = "S3 bucket holding Terraform remote state — reference this in terraform/main/backend.tf"
}

output "tflock_table" {
  value       = aws_dynamodb_table.tflock.name
  description = "DynamoDB table used for Terraform state locking"
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}
