locals {
  # Everyone who may sign in to the hub, keyed by the email of their Google account. An admin also gets a user in realm
  # master with realm role admin, which administers every realm, and signs in to the admin console with Google too.
  users = {
    "arikkfir@gmail.com" = { first_name = "Arik", last_name = "Kfir", admin = true }
  }
}

resource "keycloak_user" "this" {
  for_each = local.users

  realm_id       = keycloak_realm.hub.id
  username       = each.key
  email          = each.key
  email_verified = true
  first_name     = each.value.first_name
  last_name      = each.value.last_name
  enabled        = true
}

resource "keycloak_user" "admin" {
  for_each = { for email, user in local.users : email => user if user.admin }

  realm_id       = data.keycloak_realm.master.id
  username       = each.key
  email          = each.key
  email_verified = true
  first_name     = each.value.first_name
  last_name      = each.value.last_name
  enabled        = true
}

data "keycloak_role" "admin" {
  realm_id = data.keycloak_realm.master.id
  name     = "admin"
}

resource "keycloak_user_roles" "admin" {
  for_each = keycloak_user.admin

  realm_id = data.keycloak_realm.master.id
  user_id  = each.value.id
  role_ids = [data.keycloak_role.admin.id]
  # Leaves the user's default roles alone.
  exhaustive = false
}
