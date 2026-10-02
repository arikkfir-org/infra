locals {
  # infra's GitHub tokens and Keycloak credentials: only infra's pipelines read them, so no Kubernetes Secret ever holds
  # them (see iam.tf).
  pipeline_secrets = toset(["infra-plan-github-pat", "infra-apply-github-pat", "infra-plan-keycloak-secret", "infra-apply-keycloak-secret"])
}

# Containers only: values are added by hand (`gcloud secrets versions add <name> --data-file=-`), except the Keycloak
# clients' secrets, which terraform/keycloak generates and writes.
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
    "keycloak-bootstrap-admin",
    "keycloak-google-client-secret",
    "keycloak-hub-client-secret",
    "infra-plan-github-pat",
    "infra-apply-github-pat",
    "infra-plan-keycloak-secret",
    "infra-apply-keycloak-secret",
  ])

  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}
