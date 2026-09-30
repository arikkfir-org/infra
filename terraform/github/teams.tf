# The pull request reviewer's GitHub user. Resolving review threads takes write access, so the team has push on
# every repository; its token (Secret Manager reviewer-github-pat) is limited to pull requests.
resource "github_team" "reviewers" {
  name        = "reviewers"
  description = "Automated pull request reviewers"
  privacy     = "closed"
}

resource "github_team_membership" "reviewer" {
  team_id  = github_team.reviewers.id
  username = "arikkfir-reviewer"
  role     = "member"
}

resource "github_team_repository" "reviewers" {
  for_each = local.repositories

  team_id    = github_team.reviewers.id
  repository = github_repository.this[each.key].name
  permission = "push"
}
