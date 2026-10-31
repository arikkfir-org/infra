locals {
  # The App ID of octomaton-dev, the Octomaton GitHub App
  # (https://docs.dev.kfirs.com/octomaton/designs/octomaton-dev.md).
  octomaton_app_id = 5114814

  # Their merge queue takes one pull request at a time: infra plans each merge after the previous one was applied.
  serial_merge_queues = toset(["infra"])
}

resource "github_repository_ruleset" "default-branch" {
  for_each = local.repositories

  name        = "Default branch"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Lets a solo maintainer merge a pull request without a second reviewer.
  # OrganizationAdmin takes no actor_id (the API ignores it and the provider docs say to leave it unset).
  bypass_actors {
    actor_type  = "OrganizationAdmin"
    bypass_mode = "always"
  }

  # Role 5 is the built-in repository admin role.
  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
      allowed_merge_methods             = ["merge"]
    }

    required_status_checks {
      strict_required_status_checks_policy = false

      # Only Octomaton may report these three; a repository's own checks may come from any source.
      required_check {
        context        = "Continuous Integration"
        integration_id = local.octomaton_app_id
      }

      required_check {
        context        = "Docs"
        integration_id = local.octomaton_app_id
      }

      # tooling's organization pipeline linear: a Linear issue linked, or the label skip-linear (labels.tf).
      required_check {
        context        = "Linear"
        integration_id = local.octomaton_app_id
      }

      dynamic "required_check" {
        for_each = toset(each.value.checks)

        content {
          context = required_check.value
        }
      }
    }

    merge_queue {
      merge_method                      = "MERGE"
      grouping_strategy                 = "ALLGREEN"
      max_entries_to_build              = contains(local.serial_merge_queues, each.key) ? 1 : 5
      min_entries_to_merge              = 1
      max_entries_to_merge              = contains(local.serial_merge_queues, each.key) ? 1 : 5
      min_entries_to_merge_wait_minutes = 3
      check_response_timeout_minutes    = 60
    }
  }
}

# Holds every merge into a default branch to a merge commit, admins' included: unlike Default branch, it has no bypass
# actors. It requires no approval, so an admin still merges past Default branch's other rules, only never by squash or
# rebase; like every pull request rule, it also takes every change to the branch through a pull request. Pull requests
# into other branches may still squash or rebase (repositories.tf).
resource "github_repository_ruleset" "merge-commits" {
  for_each = local.repositories

  name        = "Merge commits"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    pull_request {
      allowed_merge_methods = ["merge"]
    }
  }
}
