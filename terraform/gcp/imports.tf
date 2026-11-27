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

# kfirs.com's own records, made by hand for GitHub Pages: the bare domain's A record and www's CNAME.
import {
  to = google_dns_record_set.kfirs
  id = "projects/${var.project_id}/managedZones/kfirs-com/rrsets/kfirs.com./A"
}

import {
  to = google_dns_record_set.kfirs_www
  id = "projects/${var.project_id}/managedZones/kfirs-com/rrsets/www.kfirs.com./CNAME"
}

