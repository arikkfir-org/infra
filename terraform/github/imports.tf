# Repositories that existed before this repository; import adopts them. Repositories added to
# local.repositories later are created instead, so do not extend this list.
import {
  for_each = toset([".github", "docs", "infra", "delivery", "octomaron", "tooling"])
  to       = github_repository.this[each.key]
  id       = each.key
}
