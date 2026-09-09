# 3 k3s nodes, t3.small (locked sizing decision — see project notes: real
# ₹300/day budget covers t3.small comfortably even worst-case, prioritizing
# "must actually run properly" over squeezing into free-tier micro).
#
# k3s itself is NOT installed via user_data — that install is done by hand
# over SSH (README "k3s cluster bring-up" section), deliberately, since
# hands-on k3s install/join is one of the confirmed skill-gap areas this
# whole project exists to close. user_data here only does baseline OS prep.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.project}-admin"
  public_key = file(var.ssh_public_key_path)
}

locals {
  node_user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    apt-get update -y
    apt-get install -y curl apt-transport-https ca-certificates
  EOF
}

resource "aws_instance" "prod_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.k3s_node.id]
  iam_instance_profile        = aws_iam_instance_profile.k3s_node.name
  key_name                    = aws_key_pair.admin.key_name
  associate_public_ip_address = true
  user_data                   = local.node_user_data

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project}-prod-server"
    Project = var.project
    Cluster = "prod"
    Role    = "server"
  }
}

resource "aws_instance" "prod_agent" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public[1].id
  vpc_security_group_ids      = [aws_security_group.k3s_node.id]
  iam_instance_profile        = aws_iam_instance_profile.k3s_node.name
  key_name                    = aws_key_pair.admin.key_name
  associate_public_ip_address = true
  user_data                   = local.node_user_data

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project}-prod-agent"
    Project = var.project
    Cluster = "prod"
    Role    = "agent"
  }
}

resource "aws_instance" "nonprod_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.k3s_node.id]
  iam_instance_profile        = aws_iam_instance_profile.k3s_node.name
  key_name                    = aws_key_pair.admin.key_name
  associate_public_ip_address = true
  user_data                   = local.node_user_data

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project}-nonprod-node"
    Project = var.project
    Cluster = "nonprod"
    Role    = "server" # single-node k3s cluster hosting dev/qa/staging namespaces
  }
}
