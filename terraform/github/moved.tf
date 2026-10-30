# Repository devhub was renamed cobranch (ENG-221): its objects keep their state under the new key, and GitHub renames
# the repository in place, redirecting the old name. Remove once applied.
moved {
  from = github_repository.this["devhub"]
  to   = github_repository.this["cobranch"]
}

moved {
  from = github_repository_vulnerability_alerts.this["devhub"]
  to   = github_repository_vulnerability_alerts.this["cobranch"]
}

moved {
  from = github_repository_dependabot_security_updates.this["devhub"]
  to   = github_repository_dependabot_security_updates.this["cobranch"]
}

moved {
  from = github_repository_autolink_reference.linear["devhub"]
  to   = github_repository_autolink_reference.linear["cobranch"]
}

moved {
  from = github_repository_ruleset.default-branch["devhub"]
  to   = github_repository_ruleset.default-branch["cobranch"]
}

moved {
  from = github_team_repository.reviewers["devhub"]
  to   = github_team_repository.reviewers["cobranch"]
}

moved {
  from = github_issue_label.skip_linear["devhub"]
  to   = github_issue_label.skip_linear["cobranch"]
}
