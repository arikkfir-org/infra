resource "keycloak_realm" "hub" {
  realm        = "hub"
  display_name = "kfirs hub"

  # Users exist only because Terraform declares them (users.tf).
  registration_allowed     = false
  reset_password_allowed   = false
  login_with_email_allowed = true
  duplicate_emails_allowed = false

  # Longer than oauth2-proxy's 5-minute refresh, so the ID token it hands Argo CD never expires first.
  access_token_lifespan    = "10m"
  sso_session_idle_timeout = "168h"
  sso_session_max_lifespan = "720h"

  lifecycle {
    prevent_destroy = true
  }
}

# Browser logins go straight to Google: an existing session, or the Google redirect.
resource "keycloak_authentication_flow" "browser_google" {
  realm_id = keycloak_realm.hub.id
  alias    = "browser-google"
}

resource "keycloak_authentication_execution" "cookie" {
  realm_id          = keycloak_realm.hub.id
  parent_flow_alias = keycloak_authentication_flow.browser_google.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

resource "keycloak_authentication_execution" "google_redirect" {
  realm_id          = keycloak_realm.hub.id
  parent_flow_alias = keycloak_authentication_flow.browser_google.alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution_config" "google_redirect" {
  realm_id     = keycloak_realm.hub.id
  execution_id = keycloak_authentication_execution.google_redirect.id
  alias        = "google"
  config = {
    defaultProvider = keycloak_oidc_google_identity_provider.google.alias
  }
}

# First Google login: link to the user with the same email, and refuse anyone Terraform didn't create.
resource "keycloak_authentication_flow" "existing_users_only" {
  realm_id = keycloak_realm.hub.id
  alias    = "existing-users-only"
}

resource "keycloak_authentication_execution" "detect_existing_user" {
  realm_id          = keycloak_realm.hub.id
  parent_flow_alias = keycloak_authentication_flow.existing_users_only.alias
  authenticator     = "idp-detect-existing-broker-user"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution" "link_existing_user" {
  realm_id          = keycloak_realm.hub.id
  parent_flow_alias = keycloak_authentication_flow.existing_users_only.alias
  authenticator     = "idp-auto-link"
  requirement       = "REQUIRED"
  priority          = 20
}

resource "keycloak_authentication_bindings" "hub" {
  realm_id     = keycloak_realm.hub.id
  browser_flow = keycloak_authentication_flow.browser_google.alias
}

# The client secret stays in Kubernetes: Keycloak resolves the vault reference from a mounted file.
resource "keycloak_oidc_google_identity_provider" "google" {
  realm                         = keycloak_realm.hub.id
  client_id                     = "8909046976-i0f5h1b5t5dvggl4qbejap1h8nkmj217.apps.googleusercontent.com"
  client_secret                 = "$${vault.google-client-secret}"
  trust_email                   = true
  sync_mode                     = "IMPORT"
  default_scopes                = "openid email profile"
  first_broker_login_flow_alias = keycloak_authentication_flow.existing_users_only.alias
}
