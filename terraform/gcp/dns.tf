locals {
  # Pre-existing public zones, adopted through imports.tf. Keys are Cloud DNS zone names. kfirfamily.com is unused.
  dns_zones = {
    "kfirs-com"      = "kfirs.com"
    "kfirfamily-com" = "kfirfamily.com"
  }

  hub_zone = replace(var.domain, ".", "-")

  # Host (left of var.domain) => Traefik gateway whose load balancer IP (network.tf) serves it.
  ingress_hosts = {
    argocd    = "protected"
    tekton    = "protected"
    grafana   = "protected"
    traefik   = "protected"
    nui       = "protected"
    auth      = "public"
    octomaron = "public"
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
