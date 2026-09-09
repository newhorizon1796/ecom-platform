# k3s node security group.
#
# - SSH (22) and kube-API (6443): admin_cidr only — never open these to the world.
# - All traffic between members of this SG: covers k3s's internal needs
#   (flannel VXLAN 8472/udp, kubelet 10250, etcd if ever HA, NodePort range)
#   without hand-enumerating every port k3s uses internally.
# - 80/443: open to the world — this is the actual public web traffic path,
#   arriving via the NLB → NodePort → Kong.
resource "aws_security_group" "k3s_node" {
  name        = "${var.project}-k3s-node"
  description = "k3s node traffic: SSH/kube-API restricted to admin, HTTP/HTTPS public, node-to-node open within the SG"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-k3s-node"
    Project = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_admin" {
  security_group_id = aws_security_group.k3s_node.id
  description       = "SSH from admin IP only"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port            = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "kube_api_admin" {
  security_group_id = aws_security_group.k3s_node.id
  description       = "k3s API server from admin IP only"
  cidr_ipv4         = var.admin_cidr
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http_public" {
  security_group_id = aws_security_group.k3s_node.id
  description       = "HTTP - public, arrives via NLB"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https_public" {
  security_group_id = aws_security_group.k3s_node.id
  description       = "HTTPS - public, arrives via NLB"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "self_all" {
  security_group_id            = aws_security_group.k3s_node.id
  description                  = "All traffic between k3s nodes themselves (flannel, kubelet, NodePort range, etc.)"
  referenced_security_group_id = aws_security_group.k3s_node.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "node_all_egress" {
  security_group_id = aws_security_group.k3s_node.id
  description        = "Unrestricted egress"
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol        = "-1"
}

# RDS security group — only reachable from k3s nodes, nothing else.
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds"
  description = "MySQL access from k3s nodes only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-rds"
    Project = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from k3s nodes"
  referenced_security_group_id = aws_security_group.k3s_node.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "rds_all_egress" {
  security_group_id = aws_security_group.rds.id
  description        = "Unrestricted egress"
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol        = "-1"
}
