# Zones that existed before this repository; import adopts them without touching their records.
import {
  for_each = toset(["kfirs-com", "kfirfamily-com"])
  to       = google_dns_managed_zone.this[each.key]
  id       = "projects/${var.project_id}/managedZones/${each.key}"
}
