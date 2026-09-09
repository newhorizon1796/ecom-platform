# One shared RDS MySQL instance (free-tier db.t3.micro) — separate logical
# databases for prod and staging created manually after the instance is up
# (Terraform's AWS provider has no resource for "CREATE DATABASE" inside an
# instance; that's a SQL step, documented in the README once a k3s node
# exists to run mysql client from — RDS SG only allows traffic from the
# k3s-node SG, not directly from admin_cidr).
#
# dev/qa use an in-cluster MySQL pod instead (item 12 of the spec) — not
# provisioned here.

resource "random_password" "rds_master" {
  length  = 24
  special = false # avoid characters that need extra escaping in connection strings / k8s secrets
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Project = var.project
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage     = 20 # gp3 minimum
  storage_type           = "gp3"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # reachable only from within the VPC (k3s nodes), not the internet

  username = "admin"
  password = random_password.rds_master.result

  # Ephemeral practice project — no need for backups/snapshots/HA that
  # outlive a one-day build-and-tear-down cycle.
  backup_retention_period = 0
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Project = var.project
  }
}

resource "aws_secretsmanager_secret" "rds_master" {
  name        = "${var.project}/rds-master"
  description = "RDS MySQL master credentials, synced into the cluster via External Secrets Operator"

  # Ephemeral project — force_overwrite lets terraform destroy → apply cycles
  # recreate this cleanly without waiting out Secrets Manager's default
  # recovery window.
  recovery_window_in_days = 0

  tags = {
    Project = var.project
  }
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.rds_master.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
  })
}

# dev/qa use an in-cluster MySQL pod instead of RDS (item 12 of the spec),
# but "no hardcoded secrets anywhere" (item 8) applies just as much there —
# this secret is synced into the nonprod cluster the same way rds_master is
# synced into prod, via External Secrets Operator.
resource "random_password" "incluster_mysql" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "incluster_mysql" {
  name                     = "${var.project}/incluster-mysql"
  description              = "Root/app password for the dev/qa in-cluster MySQL pod"
  recovery_window_in_days  = 0

  tags = {
    Project = var.project
  }
}

resource "aws_secretsmanager_secret_version" "incluster_mysql" {
  secret_id = aws_secretsmanager_secret.incluster_mysql.id
  secret_string = jsonencode({
    username = "root"
    password = random_password.incluster_mysql.result
    database = "ecom"
  })
}
