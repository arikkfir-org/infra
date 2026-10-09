locals {
  # Bump a version to rotate that secret: Terraform writes a new value to Keycloak and to Secret Manager.
  secret_versions = {
    hub             = "1"
    fin-e2e         = "1"
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

# The hub's tools admit only group admins (delivery's admins middleware), and fin-api tells test users by fin-e2e.
resource "keycloak_openid_group_membership_protocol_mapper" "hub_groups" {
  realm_id            = keycloak_realm.hub.id
  client_id           = keycloak_openid_client.hub.id
  name                = "groups"
  claim_name          = "groups"
  full_path           = false
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Fin's local development: its dev server signs a developer in through this client, as oauth2-proxy does in the
# cluster, and the local fin-api accepts its ID tokens. Public, with PKCE: its codes reach only the developer's own
# machine, and no deployed fin-api accepts its tokens.
resource "keycloak_openid_client" "fin_local" {
  realm_id                     = keycloak_realm.hub.id
  client_id                    = "fin-local"
  name                         = "Fin's local development"
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  pkce_code_challenge_method   = "S256"
  valid_redirect_uris          = ["http://localhost:5173/oauth2/callback"]
}

# fin-api tells test users by fin-e2e locally too.
resource "keycloak_openid_group_membership_protocol_mapper" "fin_local_groups" {
  realm_id            = keycloak_realm.hub.id
  client_id           = keycloak_openid_client.fin_local.id
  name                = "groups"
  claim_name          = "groups"
  full_path           = false
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Fin's end-to-end runs: they create, sign in and delete group fin-e2e's members, and nobody else
# (docs/infra/designs/test-users.md). ci-fin-ci reads the secret at run time.
resource "keycloak_openid_client" "fin_e2e" {
  realm_id                 = keycloak_realm.hub.id
  client_id                = "fin-e2e"
  name                     = "Fin's end-to-end runs"
  access_type              = "CONFIDENTIAL"
  service_accounts_enabled = true
  standard_flow_enabled    = false

  client_secret_wo         = ephemeral.random_password.secret["fin-e2e"].result
  client_secret_wo_version = local.secret_versions["fin-e2e"]
}

resource "google_secret_manager_secret_version" "fin_e2e" {
  secret                 = "projects/${var.project_id}/secrets/ci-fin-e2e-keycloak-secret"
  secret_data_wo         = ephemeral.random_password.secret["fin-e2e"].result
  secret_data_wo_version = local.secret_versions["fin-e2e"]
}

# The resource server of realm hub's admin permissions, which turning them on creates. Like master-realm
# (pipelines.tf), looked up through the SAML data source, which reads no secret.
data "keycloak_saml_client" "admin_permissions" {
  realm_id  = keycloak_realm.hub.id
  client_id = "admin-permissions"

  depends_on = [keycloak_realm.hub]
}

# Client fin-e2e's service account user, by a user policy: searches, such as the runs' lookup of the group, filter in
# the database through partial evaluation, which evaluates user, group, role and aggregated policies, not client ones.
resource "keycloak_openid_client_user_policy" "fin_e2e" {
  realm_id           = keycloak_realm.hub.id
  resource_server_id = data.keycloak_saml_client.admin_permissions.id
  name               = "fin-e2e"
  users              = [keycloak_openid_client.fin_e2e.service_account_user_id]
  logic              = "POSITIVE"
  decision_strategy  = "UNANIMOUS"
}

# view with manage-members and manage-membership lets it create users into the group (Keycloak 26.8).
resource "keycloak_group_admin_permissions" "fin_e2e_members" {
  realm_id          = keycloak_realm.hub.id
  name              = "fin-e2e-members"
  description       = "Fin's end-to-end runs create, sign in and delete the group's members"
  decision_strategy = "UNANIMOUS"
  group_ids         = [keycloak_group.fin_e2e.id]
  scopes            = ["view", "view-members", "manage-members", "manage-membership"]
  policies          = [keycloak_openid_client_user_policy.fin_e2e.id]
}
