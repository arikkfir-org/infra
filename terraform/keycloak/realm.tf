resource "keycloak_realm" "hub" {
  realm        = "hub"
  display_name = "kfirs hub"

  # People exist only because Terraform declares them (users.tf); test users only while a run of Fin's end-to-end suite
  # needs them (docs/infra/designs/test-users.md).
  registration_allowed     = false
  reset_password_allowed   = false
  login_with_email_allowed = true
  duplicate_emails_allowed = false

  # Longer than oauth2-proxy's 5-minute refresh, so the ID token it hands Argo CD never expires first.
  access_token_lifespan    = "10m"
  sso_session_idle_timeout = "168h"
  sso_session_max_lifespan = "720h"

  # Client fin-e2e's rights over group fin-e2e (clients.tf).
  admin_permissions_enabled = true

  # No brute-force detection, though the login page's password form is public: it would count wrong passwords against
  # people too, who have none, and lock them out of Google sign-in (docs/infra/designs/test-users.md).

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  # Realms whose people sign in with Google: hub for everyone users.tf declares, master for its admins (the console).
  google_realms = {
    hub    = keycloak_realm.hub.id
    master = data.keycloak_realm.master.id
  }

  # Where only people sign in, logins go straight to Google.
  google_redirect_realms = {
    master = data.keycloak_realm.master.id
  }

  browser_flows = {
    hub    = keycloak_authentication_flow.browser_form.alias
    master = keycloak_authentication_flow.browser_google["master"].alias
  }
}

# Realm hub's login page: an existing session, or the password form, which only test users can pass, beside a button
# for Google.
resource "keycloak_authentication_flow" "browser_form" {
  realm_id = keycloak_realm.hub.id
  alias    = "browser-form"
}

resource "keycloak_authentication_execution" "form_cookie" {
  realm_id          = keycloak_realm.hub.id
  parent_flow_alias = keycloak_authentication_flow.browser_form.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

resource "keycloak_authentication_subflow" "forms" {
  realm_id          = keycloak_realm.hub.id
  parent_flow_alias = keycloak_authentication_flow.browser_form.alias
  alias             = "browser-form forms"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution" "password_form" {
  realm_id          = keycloak_realm.hub.id
  parent_flow_alias = keycloak_authentication_subflow.forms.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

# Browser logins go straight to Google: an existing session, or the Google redirect.
resource "keycloak_authentication_flow" "browser_google" {
  for_each = local.google_redirect_realms

  realm_id = each.value
  alias    = "browser-google"
}

resource "keycloak_authentication_execution" "cookie" {
  for_each = local.google_redirect_realms

  realm_id          = each.value
  parent_flow_alias = keycloak_authentication_flow.browser_google[each.key].alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

resource "keycloak_authentication_execution" "google_redirect" {
  for_each = local.google_redirect_realms

  realm_id          = each.value
  parent_flow_alias = keycloak_authentication_flow.browser_google[each.key].alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution_config" "google_redirect" {
  for_each = local.google_redirect_realms

  realm_id     = each.value
  execution_id = keycloak_authentication_execution.google_redirect[each.key].id
  alias        = "google"
  config = {
    defaultProvider = keycloak_oidc_google_identity_provider.google[each.key].alias
  }
}

# First Google login: link to the user with the same email, and refuse anyone Terraform didn't create.
resource "keycloak_authentication_flow" "existing_users_only" {
  for_each = local.google_realms

  realm_id = each.value
  alias    = "existing-users-only"
}

resource "keycloak_authentication_execution" "detect_existing_user" {
  for_each = local.google_realms

  realm_id          = each.value
  parent_flow_alias = keycloak_authentication_flow.existing_users_only[each.key].alias
  authenticator     = "idp-detect-existing-broker-user"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution" "link_existing_user" {
  for_each = local.google_realms

  realm_id          = each.value
  parent_flow_alias = keycloak_authentication_flow.existing_users_only[each.key].alias
  authenticator     = "idp-auto-link"
  requirement       = "REQUIRED"
  priority          = 20
}

resource "keycloak_authentication_bindings" "this" {
  for_each = local.google_realms

  realm_id     = each.value
  browser_flow = local.browser_flows[each.key]
}

# The client secret stays in Kubernetes: Keycloak resolves the vault reference from a mounted file,
# <realm>_google-client-secret.
resource "keycloak_oidc_google_identity_provider" "google" {
  for_each = local.google_realms

  realm                         = each.value
  client_id                     = "8909046976-i0f5h1b5t5dvggl4qbejap1h8nkmj217.apps.googleusercontent.com"
  client_secret                 = "$${vault.google-client-secret}"
  trust_email                   = true
  sync_mode                     = "IMPORT"
  default_scopes                = "openid email profile"
  first_broker_login_flow_alias = keycloak_authentication_flow.existing_users_only[each.key].alias
}

# Realm hub's sign-in, from before realm master shared it.
moved {
  from = keycloak_authentication_flow.browser_google
  to   = keycloak_authentication_flow.browser_google["hub"]
}

moved {
  from = keycloak_authentication_execution.cookie
  to   = keycloak_authentication_execution.cookie["hub"]
}

moved {
  from = keycloak_authentication_execution.google_redirect
  to   = keycloak_authentication_execution.google_redirect["hub"]
}

moved {
  from = keycloak_authentication_execution_config.google_redirect
  to   = keycloak_authentication_execution_config.google_redirect["hub"]
}

moved {
  from = keycloak_authentication_flow.existing_users_only
  to   = keycloak_authentication_flow.existing_users_only["hub"]
}

moved {
  from = keycloak_authentication_execution.detect_existing_user
  to   = keycloak_authentication_execution.detect_existing_user["hub"]
}

moved {
  from = keycloak_authentication_execution.link_existing_user
  to   = keycloak_authentication_execution.link_existing_user["hub"]
}

moved {
  from = keycloak_authentication_bindings.hub
  to   = keycloak_authentication_bindings.this["hub"]
}

moved {
  from = keycloak_oidc_google_identity_provider.google
  to   = keycloak_oidc_google_identity_provider.google["hub"]
}
