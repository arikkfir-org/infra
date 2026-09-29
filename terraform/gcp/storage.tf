# Bucket => public access prevention. arikkfir-claude is public: anyone can read objects by URL
# (https://storage.googleapis.com/<bucket>/<path>), nobody can list them anonymously. arikkfir-docs is private; the
# docs site in the cluster serves it. Readers and writers are granted in iam.tf.
resource "google_storage_bucket" "this" {
  for_each = {
    "arikkfir-docs"   = "enforced"
    "arikkfir-claude" = "inherited"
  }

  name                        = each.key
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = each.value

  depends_on = [google_project_service.this]
}
