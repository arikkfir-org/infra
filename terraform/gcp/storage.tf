# Bucket => public access prevention and the age in days after which objects are deleted (null keeps them).
# arikkfir-claude is public: anyone can read objects by URL (https://storage.googleapis.com/<bucket>/<path>), nobody can
# list them anonymously. arikkfir-docs is private; the docs site in the cluster serves it, and it keeps the layers
# forever. arikkfir-tests holds what CI's tests keep, such as each run's report, which the tests site serves, for 30
# days. arikkfir-fin and arikkfir-fin-pull-requests hold Fin's scrape videos, traces and raw statements, which only
# fin-api serves. arikkfir-fin-ci-cache holds Fin's CI cache, which its release pipeline saves on main.
# arikkfir-octomaton-ci-cache holds Octomaton's CI caches: main's, which its main pipeline saves, and each pull
# request's, which its ci saves. arikkfir-cobranch is the bucket of Cobranch's demo installation, which only its servers
# reach. Readers and the writers are granted in iam.tf.
resource "google_storage_bucket" "this" {
  for_each = {
    "arikkfir-docs"               = { public_access_prevention = "enforced", delete_after_days = null }
    "arikkfir-tests"              = { public_access_prevention = "enforced", delete_after_days = 30 }
    "arikkfir-claude"             = { public_access_prevention = "inherited", delete_after_days = null }
    "arikkfir-fin"                = { public_access_prevention = "enforced", delete_after_days = 30 }
    "arikkfir-fin-pull-requests"  = { public_access_prevention = "enforced", delete_after_days = 7 }
    "arikkfir-fin-ci-cache"       = { public_access_prevention = "enforced", delete_after_days = 14 }
    "arikkfir-octomaton-ci-cache" = { public_access_prevention = "enforced", delete_after_days = 14 }
    "arikkfir-cobranch"           = { public_access_prevention = "enforced", delete_after_days = null }
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

  depends_on = [google_project_service.this]
}
