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
