# Federation for automation outside GCP. Deliberately has no role grants; grant per use case when one comes up.
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "hub-github"
  display_name              = "Hub GitHub"
  description               = "GitHub Actions in the arikkfir-org organization."

  depends_on = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions"
  description                        = "OIDC tokens of GitHub Actions workflows in arikkfir-org."

  attribute_condition = "assertion.repository_owner == 'arikkfir-org'"
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.ref"              = "assertion.ref"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
