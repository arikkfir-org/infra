locals {
  # Everyone who may sign in to the hub, keyed by the email of their Google account.
  users = {
    "arikkfir@gmail.com" = { first_name = "Arik", last_name = "Kfir" }
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
