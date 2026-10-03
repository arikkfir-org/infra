locals {
  # Public zones; keys are Cloud DNS zone names. kfirs.com and kfirfamily.com existed before and are adopted through
  # imports.tf (kfirfamily.com is unused); octomaton.dev is Octomaton's own domain, delegated to this zone at its
  # registrar.
  dns_zones = {
    "kfirs-com"      = "kfirs.com"
    "kfirfamily-com" = "kfirfamily.com"
    "octomaton-dev"  = "octomaton.dev"
  }

  hub_zone = replace(var.domain, ".", "-")

  # Host (left of var.domain) => Traefik gateway whose load balancer IP (network.tf) serves it.
  ingress_hosts = {
    "argocd.dev"  = "protected"
    "tekton.dev"  = "protected"
    "grafana.dev" = "protected"
    "traefik.dev" = "protected"
    "nui.dev"     = "protected"
    "docs.dev"    = "protected"
    auth          = "public"
    # Keycloak: realm hub, and its admin console behind the hub's sign-in.
    id         = "public"
    "admin.id" = "protected"
    # The privacy policy and terms of service, from the docs site.
    legal = "public"
    # Fin: production, and every pull request's environment (pr-<number>.app.fin.dev, pr-<number>.api.fin.dev). The
    # wildcards sit one level down, where their certificate's DNS-01 challenge records live: an existing
    # _acme-challenge.app.fin.dev would stop a *.fin.dev from answering for the names below app.fin.dev.
    "app.fin"       = "protected"
    "api.fin"       = "protected"
    "*.app.fin.dev" = "protected"
    "*.api.fin.dev" = "protected"
    # Fin's Go import page (fin.kfirs.com/apps/api): the go command fetches it without signing in.
    fin = "public"
  }
}

# Attributes mirror the live zones exactly so that importing them plans no changes.
resource "google_dns_managed_zone" "this" {
  for_each = local.dns_zones

  name        = each.key
  dns_name    = "${each.value}."
  description = "${each.value} DNS zone"
  visibility  = "public"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_dns_record_set" "ingress" {
  for_each = local.ingress_hosts

  managed_zone = google_dns_managed_zone.this[local.hub_zone].name
  name         = "${each.key}.${google_dns_managed_zone.this[local.hub_zone].dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.ingress[each.value].address]
}

# octomaton.dev itself: Octomaton's webhook and Go import page, both on the public gateway.
resource "google_dns_record_set" "octomaton" {
  managed_zone = google_dns_managed_zone.this["octomaton-dev"].name
  name         = google_dns_managed_zone.this["octomaton-dev"].dns_name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.ingress["public"].address]
}
