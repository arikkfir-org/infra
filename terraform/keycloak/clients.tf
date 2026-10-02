locals {
  # Bump a version to rotate that secret: Terraform writes a new value to Keycloak and to Secret Manager.
  secret_versions = {
    hub             = "1"
    terraform-plan  = "1"
    terraform-apply = "1"
  }
}

ephemeral "random_password" "secret" {
  for_each = local.secret_versions

  length  = 48
  special = false
}

# oauth2-proxy and Argo CD share this client: Argo CD verifies the ID tokens oauth2-proxy forwards to it.
resource "keycloak_openid_client" "hub" {
  realm_id                     = keycloak_realm.hub.id
  client_id                    = "hub"
  name                         = "Hub (oauth2-proxy, Argo CD)"
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  valid_redirect_uris = [
    "https://auth.kfirs.com/oauth2/callback",
    "https://argocd.dev.kfirs.com/auth/callback",
  ]

  client_secret_wo         = ephemeral.random_password.secret["hub"].result
  client_secret_wo_version = local.secret_versions.hub
}

resource "google_secret_manager_secret_version" "hub" {
  secret                 = "projects/${var.project_id}/secrets/keycloak-hub-client-secret"
  secret_data_wo         = ephemeral.random_password.secret["hub"].result
  secret_data_wo_version = local.secret_versions.hub
}
