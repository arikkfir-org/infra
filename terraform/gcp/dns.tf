locals {
  # Public zones; keys are Cloud DNS zone names. kfirs.com and kfirfamily.com existed before and are adopted through
  # imports.tf (kfirfamily.com is unused); octomaton.dev is Octomaton's own domain, and cobranch.dev and cobranch.app
  # Cobranch's (the product, with its site and Go import page, and its hosted service), each delegated to its zone at
  # Namecheap by root namecheap.
  dns_zones = {
    "kfirs-com"      = "kfirs.com"
    "kfirfamily-com" = "kfirfamily.com"
    "octomaton-dev"  = "octomaton.dev"
    "cobranch-dev"   = "cobranch.dev"
    "cobranch-app"   = "cobranch.app"
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
    "tests.dev"   = "protected"
    # Cobranch's demo, and its pull requests' previews (pr-<number>.cobranch.dev) beside it: hosts under kfirs.com, behind
    # the hub's sign-in, not the cobranch.dev domain. The previews' certificate's DNS-01 challenge record,
    # _acme-challenge.cobranch.dev, is a sibling of the names the wildcard answers for, which it leaves alone.
    "cobranch.dev"   = "protected"
    "*.cobranch.dev" = "protected"
    # Their Git servers, on the public gateway since Git clients can't pass the hub's sign-in: the demo's at
    # git.cobranch.dev, each preview's at pr-<number>.git.cobranch.dev, which serves its pull request's own code, as the
    # owner accepted on 2026-11-01. A name under git.cobranch.dev escapes the wildcard above once git.cobranch.dev
    # exists, so it has a wildcard of its own.
    "git.cobranch.dev"   = "public"
    "*.git.cobranch.dev" = "public"
    auth                 = "public"
    # Keycloak: realm hub, and its admin console behind the hub's sign-in.
    id         = "public"
    "admin.id" = "protected"
    # The privacy policy and terms of service, from the docs site.
    legal = "public"
    # Fin: production, and every pull request's environment (pr-<number>.app.dev.fin), each with its API under /api.
    # The wildcard sits where its certificate's DNS-01 challenge record lives: an existing _acme-challenge.app.dev.fin
    # would stop a wildcard higher up from answering for the names below app.dev.fin.
    "app.fin"       = "protected"
    "*.app.dev.fin" = "protected"
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

# cobranch.dev itself: Cobranch's Go import page, on the public gateway.
resource "google_dns_record_set" "cobranch" {
  managed_zone = google_dns_managed_zone.this["cobranch-dev"].name
  name         = google_dns_managed_zone.this["cobranch-dev"].dns_name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.ingress["public"].address]
}

# cobranch.app, Cobranch's hosted service: the Console and its APIs at the apex, and its Git server at git.cobranch.app,
# both on the public gateway, where Cobranch signs everyone in itself.
resource "google_dns_record_set" "cobranch_app" {
  for_each = toset(["cobranch.app", "git.cobranch.app"])

  managed_zone = google_dns_managed_zone.this["cobranch-app"].name
  name         = "${each.key}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.ingress["public"].address]
}
