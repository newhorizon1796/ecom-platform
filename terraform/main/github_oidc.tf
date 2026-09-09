# Lets GitHub Actions' hosted runners assume an AWS role via OIDC — no
# static AWS access keys stored as GitHub secrets. Scoped to only this repo,
# only for pushing images to these two ECR repos.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud"        = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:repository" = "newhorizon1796/ecom-platform"
        }
        StringLike = {
          # AWS requires the trust policy to condition on sub or
          # job_workflow_ref specifically (not just other claims like
          # "repository" alone) — a guardrail against overly-broad OIDC
          # trust policies. GitHub's sub format now embeds numeric owner/repo
          # IDs (discovered by decoding a real token during setup):
          # "repo:owner@ownerID/repo@repoID:ref:refs/heads/BRANCH"
          "token.actions.githubusercontent.com:sub" = "repo:newhorizon1796@287635122/ecom-platform@1362452566:*"
        }
      }
    }]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_policy" "github_actions_ecr" {
  name        = "${var.project}-github-actions-ecr"
  description = "Push access to this project's ECR repos, for GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = [
          aws_ecr_repository.frontend.arn,
          aws_ecr_repository.backend.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}
