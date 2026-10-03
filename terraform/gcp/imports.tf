# Zones that existed before this repository; import adopts them without touching their records.
import {
  for_each = toset(["kfirs-com", "kfirfamily-com"])
  to       = google_dns_managed_zone.this[each.key]
  id       = "projects/${var.project_id}/managedZones/${each.key}"
}

# claude-code@'s viewer role, granted by hand before this repository managed it.
import {
  to = google_project_iam_member.claude_code
  id = "${var.project_id} roles/viewer ${local.principals.claude_code}"
}
