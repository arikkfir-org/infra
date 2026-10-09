data "keycloak_realm" "master" {
  realm = "master"
}

# The master realm's clients for administering realms master and hub. Keycloak shows nobody their secrets, which the
# OpenID client data source always reads, so the SAML one looks them up.
data "keycloak_saml_client" "master_realm" {
  realm_id  = data.keycloak_realm.master.id
  client_id = "master-realm"
}

data "keycloak_saml_client" "hub_realm" {
  realm_id  = data.keycloak_realm.master.id
  client_id = "hub-realm"
}

# infra's pipelines: terraform-plan reads (pull requests), terraform-apply administers (merges to main). The first
# apply runs by hand as the bootstrap admin.
resource "keycloak_openid_client" "terraform" {
  for_each = toset(["plan", "apply"])

  realm_id                 = data.keycloak_realm.master.id
  client_id                = "terraform-${each.key}"
  access_type              = "CONFIDENTIAL"
  service_accounts_enabled = true
  standard_flow_enabled    = false

  client_secret_wo         = ephemeral.random_password.secret["terraform-${each.key}"].result
  client_secret_wo_version = local.secret_versions["terraform-${each.key}"]
}

resource "google_secret_manager_secret_version" "terraform" {
  for_each = toset(["plan", "apply"])

  secret                 = "projects/${var.project_id}/secrets/infra-${each.key}-keycloak-secret"
  secret_data_wo         = ephemeral.random_password.secret["terraform-${each.key}"].result
  secret_data_wo_version = local.secret_versions["terraform-${each.key}"]
}

locals {
  # Pull request plans don't refresh: Keycloak shows a client's secret only to client managers, and the provider reads
  # the secret to refresh a client. So terraform-plan reads only the data sources: realm master and its clients, and
  # realm hub's clients, for client admin-permissions, which hub's admin permissions hang on.
  plan_roles = {
    "master/view-realm"   = { client = data.keycloak_saml_client.master_realm.id, role = "view-realm" }
    "master/view-clients" = { client = data.keycloak_saml_client.master_realm.id, role = "view-clients" }
    "hub/view-clients"    = { client = data.keycloak_saml_client.hub_realm.id, role = "view-clients" }
  }
}

resource "keycloak_openid_client_service_account_role" "plan" {
  for_each = local.plan_roles

  realm_id                = data.keycloak_realm.master.id
  service_account_user_id = keycloak_openid_client.terraform["plan"].service_account_user_id
  client_id               = each.value.client
  role                    = each.value.role
}

resource "keycloak_openid_client_service_account_realm_role" "apply" {
  realm_id                = data.keycloak_realm.master.id
  service_account_user_id = keycloak_openid_client.terraform["apply"].service_account_user_id
  role                    = "admin"
}
