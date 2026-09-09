# ECR repos for the two app images. Scan-on-push enabled as defense in depth
# alongside the Trivy scan already gating the CI pipeline (item 6/17 of the
# project spec) — cheap (no extra cost beyond storage) and catches anything
# that slips past a misconfigured CI step.

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project}/frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project}/backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project
  }
}

# Lifecycle policy: keep the last 10 images per repo, expire the rest.
# Ephemeral practice project — no need to accumulate untagged/old layers
# and pay for storage past what's actually useful for rollback practice.
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy     = data.aws_ecr_lifecycle_policy_document.keep_last_10.json
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy     = data.aws_ecr_lifecycle_policy_document.keep_last_10.json
}

data "aws_ecr_lifecycle_policy_document" "keep_last_10" {
  rule {
    priority    = 1
    description = "Keep last 10 images"

    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = 10
    }

    action {
      type = "expire"
    }
  }
}
