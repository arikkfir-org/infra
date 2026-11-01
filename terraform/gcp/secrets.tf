locals {
  # infra's GitHub tokens, Keycloak credentials and Namecheap API user and key, and Fin's end-to-end Keycloak
  # credential: only their pipelines read them, so no Kubernetes Secret ever holds them (see iam.tf).
  pipeline_secrets = toset([
    "infra-plan-github-pat",
    "infra-apply-github-pat",
    "infra-plan-keycloak-secret",
    "infra-apply-keycloak-secret",
    "infra-namecheap-api-user",
    "infra-namecheap-api-key",
    "ci-fin-e2e-keycloak-secret",
  ])
}

# Containers only: values are added by hand (`gcloud secrets versions add <name> --data-file=-`), except the Keycloak
# clients' secrets, which terraform/keycloak generates and writes. cobranch-app-google-client-secret is the secret of
# the Google OAuth client the owner made by hand for cobranch.app's sign-in.
# External Secrets Operator reads all but the pipeline secrets.
resource "google_secret_manager_secret" "this" {
  for_each = toset([
    "reviewer-deepseek-api-key",
    "reviewer-github-pat",
    "linear-api-key",
    "octomaton-github-app-id",
    "octomaton-github-private-key",
    "octomaton-github-webhook-secret",
    "oauth2-proxy-cookie-secret",
    "grafana-postgres-admin-password",
    "argocd-github-app-id",
    "argocd-github-app-private-key",
    "fin-postgres-arik-password",
    "fin-scraper-sealing-key",
    "keycloak-bootstrap-admin",
    "keycloak-google-client-secret",
    "keycloak-hub-client-secret",
    "keycloak-cobranch-client-secret",
    "cobranch-app-google-client-secret",
    "infra-plan-github-pat",
    "infra-apply-github-pat",
    "infra-plan-keycloak-secret",
    "infra-apply-keycloak-secret",
    "infra-namecheap-api-user",
    "infra-namecheap-api-key",
    "ci-fin-e2e-keycloak-secret",
  ])

  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}
