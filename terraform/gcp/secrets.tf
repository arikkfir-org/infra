# Containers only: values are added by hand (`gcloud secrets versions add <name> --data-file=-`).
# External Secrets Operator is the only reader (see iam.tf).
resource "google_secret_manager_secret" "this" {
  for_each = toset([
    "octomaron-github-app-id",
    "octomaron-github-private-key",
    "octomaron-github-webhook-secret",
    "oidc-client-secret",
    "oauth2-proxy-cookie-secret",
    "hub-authorized-emails",
  ])

  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}
