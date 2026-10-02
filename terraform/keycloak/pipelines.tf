data "keycloak_realm" "master" {
  realm = "master"
}

# The master realm's clients for administering realms hub (it exists once the realm does) and master. Keycloak shows
# nobody their secrets, which the OpenID client data source always reads, so the SAML one looks them up.
data "keycloak_saml_client" "hub_realm" {
  realm_id  = data.keycloak_realm.master.id
  client_id = "${keycloak_realm.hub.realm}-realm"
}

data "keycloak_saml_client" "master_realm" {
  realm_id  = data.keycloak_realm.master.id
  client_id = "master-realm"
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
  plan_roles = merge(
    { for role in ["view-realm", "view-clients", "view-users", "view-identity-providers", "view-events"] : "hub/${role}" => { client = data.keycloak_saml_client.hub_realm.id, role = role } },
    { for role in ["view-realm", "view-clients", "view-users"] : "master/${role}" => { client = data.keycloak_saml_client.master_realm.id, role = role } },
  )
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
