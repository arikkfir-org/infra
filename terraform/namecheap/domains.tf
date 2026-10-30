locals {
  # Domains registered at Namecheap, each delegated to the Cloud DNS zone that root gcp keeps for it, named after it
  # with dots replaced by dashes.
  domains = toset(["octomaton.dev", "cobranch.dev", "cobranch.app"])
}

data "google_compute_address" "egress" {
  name = "egress"
}

data "google_dns_managed_zone" "this" {
  for_each = local.domains

  name = replace(each.key, ".", "-")
}

# OVERWRITE: a domain's nameservers are exactly its zone's. Destroying one would put the domain back on Namecheap's
# own DNS, so none is ever destroyed.
resource "namecheap_domain_records" "this" {
  for_each = local.domains

  domain      = each.key
  mode        = "OVERWRITE"
  nameservers = [for ns in data.google_dns_managed_zone.this[each.key].name_servers : trimsuffix(ns, ".")]

  lifecycle {
    prevent_destroy = true
  }
}
