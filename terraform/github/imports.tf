# Repositories created by hand; import adopts them. A repository first added to local.repositories is created
# instead, so list only repositories that already exist.
import {
  for_each = toset([".github", "docs", "infra", "delivery", "octomaton", "tooling", "fin"])
  to       = github_repository.this[each.key]
  id       = each.key
}

# The organization exists; import adopts its settings.
import {
  to = github_organization_settings.arikkfir_org
  id = "arikkfir-org"
}
