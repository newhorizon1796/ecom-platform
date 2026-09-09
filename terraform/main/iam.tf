# IAM role for k3s EC2 nodes. Not EKS, so no IRSA — pods that need AWS API
# access (AWS Load Balancer Controller, External Secrets Operator) inherit
# permissions from the node's instance profile via the EC2 metadata service.
# Fine at this scale (single small cluster, no multi-tenant isolation need);
# a real multi-team cluster would want something like kiam/kube2iam or a
# migration to EKS + IRSA instead.

resource "aws_iam_role" "k3s_node" {
  name = "${var.project}-k3s-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_instance_profile" "k3s_node" {
  name = "${var.project}-k3s-node"
  role = aws_iam_role.k3s_node.name
}

# ECR pull access — nodes need this to pull frontend/backend images.
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Secrets Manager read — scoped to this project's secrets only, consumed by
# External Secrets Operator to sync into k8s Secret objects.
resource "aws_iam_policy" "secrets_read" {
  name        = "${var.project}-secrets-read"
  description = "Read-only access to this project's Secrets Manager secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_read" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

# AWS Load Balancer Controller — standard upstream policy (from the
# kubernetes-sigs/aws-load-balancer-controller project docs), lets the
# controller pod create/manage the NLB, target groups, listeners, SGs, etc.
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.project}-alb-controller"
  description = "Permissions for AWS Load Balancer Controller to manage the NLB fronting Kong"
  policy      = file("${path.module}/policies/alb-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# CloudWatch agent — optional but cheap, useful for node-level metrics/logs
# alongside the in-cluster Prometheus stack.
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
