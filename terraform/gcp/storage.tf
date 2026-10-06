# Bucket => public access prevention, the age in days after which objects are deleted (null keeps them), and the same
# for the objects under a prefix. arikkfir-claude is public: anyone can read objects by URL
# (https://storage.googleapis.com/<bucket>/<path>), nobody can list them anonymously. arikkfir-docs is private; the docs
# site in the cluster serves it. It keeps the layers forever, and CI runs' reports, under .reports/, for 30 days.
# arikkfir-fin and arikkfir-fin-pull-requests hold Fin's scrape videos, traces and raw statements, which only fin-api
# serves. arikkfir-fin-ci-cache holds Fin's CI cache, which its release pipeline saves on main. Readers and the writer
# are granted in iam.tf.
resource "google_storage_bucket" "this" {
  for_each = {
    "arikkfir-docs"              = { public_access_prevention = "enforced", delete_after_days = null, delete_under = { ".reports/" = 30 } }
    "arikkfir-claude"            = { public_access_prevention = "inherited", delete_after_days = null, delete_under = {} }
    "arikkfir-fin"               = { public_access_prevention = "enforced", delete_after_days = 30, delete_under = {} }
    "arikkfir-fin-pull-requests" = { public_access_prevention = "enforced", delete_after_days = 7, delete_under = {} }
    "arikkfir-fin-ci-cache"      = { public_access_prevention = "enforced", delete_after_days = 14, delete_under = {} }
  }

  name                        = each.key
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = each.value.public_access_prevention

  dynamic "lifecycle_rule" {
    for_each = each.value.delete_after_days == null ? [] : [each.value.delete_after_days]

    content {
      condition {
        age = lifecycle_rule.value
      }
      action {
        type = "Delete"
      }
    }
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.delete_under

    content {
      condition {
        age            = lifecycle_rule.value
        matches_prefix = [lifecycle_rule.key]
      }
      action {
        type = "Delete"
      }
    }
  }

  depends_on = [google_project_service.this]
}
