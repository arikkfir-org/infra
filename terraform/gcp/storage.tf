# Public buckets: anyone can read objects by URL (https://storage.googleapis.com/<bucket>/<path>), nobody can list
# them anonymously. Readers and writers are granted in iam.tf.
resource "google_storage_bucket" "public" {
  for_each = toset(["arikkfir-docs", "arikkfir-claude"])

  name                        = each.key
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  depends_on = [google_project_service.this]
}
