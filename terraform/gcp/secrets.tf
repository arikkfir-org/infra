# Containers only: values are added by hand (`gcloud secrets versions add <name> --data-file=-`).
# External Secrets Operator reads them all; infra's pipelines also read their own GitHub token (see iam.tf).
resource "google_secret_manager_secret" "this" {
  for_each = toset([
    "reviewer-deepseek-api-key",
    "reviewer-github-pat",
    "octomaton-github-app-id",
    "octomaton-github-private-key",
    "octomaton-github-webhook-secret",
    "oidc-client-secret",
    "oauth2-proxy-cookie-secret",
    "grafana-postgres-admin-password",
    "infra-plan-github-pat",
    "infra-apply-github-pat",
  ])

  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}
