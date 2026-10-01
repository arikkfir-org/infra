resource "github_organization_settings" "arikkfir_org" {
  billing_email = "arikkfir@gmail.com"
  name          = "arikkfir-org"
  description   = "A personal development hub: the home of personal projects, and of the platform they are built and run on."

  has_organization_projects     = false
  has_repository_projects       = false
  default_repository_permission = "read"

  # Repositories come from terraform/github; organization owners can still create them by hand.
  members_can_create_repositories          = false
  members_can_create_public_repositories   = false
  members_can_create_private_repositories  = false
  members_can_create_internal_repositories = false

  members_can_create_pages         = false
  members_can_create_public_pages  = false
  members_can_create_private_pages = false

  members_can_fork_private_repositories = false
  web_commit_signoff_required           = false

  lifecycle {
    # Destroying this resource would reset the billing email.
    prevent_destroy = true

    # Kept by hand: the rest of the profile. GitHub has closed down the *_enabled_for_new_repositories parameters in
    # favour of code security configurations.
    ignore_changes = [
      blog,
      company,
      email,
      location,
      twitter_username,
      advanced_security_enabled_for_new_repositories,
      dependabot_alerts_enabled_for_new_repositories,
      dependabot_security_updates_enabled_for_new_repositories,
      dependency_graph_enabled_for_new_repositories,
      secret_scanning_enabled_for_new_repositories,
      secret_scanning_push_protection_enabled_for_new_repositories,
    ]
  }
}
