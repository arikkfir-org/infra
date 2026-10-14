# Waives check Linear for a pull request that has no Linear issue (CONTRIBUTING.md, "Linear"). People add it, and
# Dependabot adds it to its pull requests through each repository's .github/dependabot.yml.
resource "github_issue_label" "skip_linear" {
  for_each = local.repositories

  repository  = github_repository.this[each.key].name
  name        = "skip-linear"
  color       = "8a93a3"
  description = "No Linear issue: check Linear passes without one"
}
