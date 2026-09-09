output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "k3s_node_sg_id" {
  value = aws_security_group.k3s_node.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "k3s_node_instance_profile" {
  value = aws_iam_instance_profile.k3s_node.name
}

output "k3s_node_role_arn" {
  value = aws_iam_role.k3s_node.arn
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "rds_master_secret_arn" {
  value = aws_secretsmanager_secret.rds_master.arn
}

output "jira_integration_secret_arn" {
  value = aws_secretsmanager_secret.jira_integration.arn
}
