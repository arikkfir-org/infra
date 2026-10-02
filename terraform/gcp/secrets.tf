locals {
  # infra's GitHub tokens: only infra's pipelines read them, so no Kubernetes Secret ever holds them (see iam.tf).
  pipeline_secrets = toset(["infra-plan-github-pat", "infra-apply-github-pat"])
}

# Containers only: values are added by hand (`gcloud secrets versions add <name> --data-file=-`).
# External Secrets Operator reads all but the pipeline secrets.
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
    "argocd-github-app-id",
    "argocd-github-app-private-key",
    "fin-postgres-arik-password",
    "infra-plan-github-pat",
    "infra-apply-github-pat",
  ])

  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}
