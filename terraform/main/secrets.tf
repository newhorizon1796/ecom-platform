# Jira integration secret — used by the webhook-receiver service (see
# README's "Monitoring + Jira alert automation" section) to call Jira's REST
# API when the CPU alert fires. Terraform creates the secret *shell* only,
# with a placeholder value — the real API token is entered directly via AWS
# CLI in a later step, so it never passes through Terraform state, this repo,
# or chat.

resource "aws_secretsmanager_secret" "jira_integration" {
  name        = "${var.project}/jira-integration"
  description = "Jira email + API token for the CPU-alert -> Jira ticket webhook-receiver"

  recovery_window_in_days = 0

  tags = {
    Project = var.project
  }

  # Never let a later `terraform apply` overwrite the real value you'll set
  # manually via `aws secretsmanager put-secret-value` — Terraform only
  # manages the secret's existence/metadata, not its content.
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_secretsmanager_secret_version" "jira_integration_placeholder" {
  secret_id     = aws_secretsmanager_secret.jira_integration.id
  secret_string = jsonencode({
    email     = "REPLACE_ME"
    api_token = "REPLACE_ME"
  })

  # Only set the placeholder on first creation — once you've filled in the
  # real value via CLI, subsequent applies won't stomp on it.
  lifecycle {
    ignore_changes = [secret_string]
  }
}
