# Zones that existed before this repository; import adopts them without touching their records.
import {
  for_each = toset(["kfirs-com", "kfirfamily-com"])
  to       = google_dns_managed_zone.this[each.key]
  id       = "projects/${var.project_id}/managedZones/${each.key}"
}

# Claude Code's service account and its viewer role, made by hand before this repository managed them.
import {
  to = google_service_account.claude_code
  id = "projects/${var.project_id}/serviceAccounts/claude-code@${var.project_id}.iam.gserviceaccount.com"
}

import {
  to = google_project_iam_member.claude_code
  id = "${var.project_id} roles/viewer ${google_service_account.claude_code.member}"
}
