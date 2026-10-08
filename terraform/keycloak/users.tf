locals {
  # Everyone who may sign in to the hub, keyed by the email of their Google account. An admin is a member of group admins,
  # whom alone the hub's tools admit, and also gets a user in realm master with realm role admin, which administers every
  # realm, and signs in to the admin console with Google too. Test users are never here: Fin's end-to-end runs create
  # them in group fin-e2e and delete them (docs/infra/designs/test-users.md).
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
  for_each = { for email, user in local.users : email => user if try(user.admin, false) }

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

resource "keycloak_group" "admins" {
  realm_id = keycloak_realm.hub.id
  name     = "admins"
}

resource "keycloak_user_groups" "admins" {
  for_each = { for email, user in local.users : email => user if try(user.admin, false) }

  realm_id  = keycloak_realm.hub.id
  user_id   = keycloak_user.this[each.key].id
  group_ids = [keycloak_group.admins.id]
  # Leaves the user's other groups alone.
  exhaustive = false
}

# Fin's test users: runs create and delete its members, which Terraform never manages.
resource "keycloak_group" "fin_e2e" {
  realm_id = keycloak_realm.hub.id
  name     = "fin-e2e"
}
