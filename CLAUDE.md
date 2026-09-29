# CLAUDE.md

## Rules

- Treat the hub reference (`hub/reference.md` in `arikkfir-org/docs`) as the contract for every name, ID, CIDR, role
  and host. If a change needs a new or different value, say so; do not diverge silently.
- Never run `terraform apply`, `destroy`, `import`, `state …`, `taint`, `force-unlock` or anything else that changes
  real infrastructure or state. Never call GCP or GitHub APIs to inspect live resources. The owner plans and applies.
- Before finishing, run `terraform fmt -recursive` at the repository root, then, in each root under `terraform/`:
  `terraform init -backend=false -input=false && terraform validate`. CI (`.tekton/ci.yaml`) runs the same checks.
- Check every argument against the pinned provider schema (`terraform providers schema -json`). Do not use deprecated
  arguments.
- After changing provider versions, run
  `terraform providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64` in that root and keep
  `.terraform.lock.hcl`.

## Conventions

- Keep one root per target (`terraform/<target>`) with state prefix = directory name. Do not add modules.
- Split files by concern: `versions.tf` (terraform block, backend, providers), `variables.tf`, `outputs.tf`,
  `imports.tf`, then one file per area.
- Name a resource after its object (`hub`, `images`, `gke_nodes`). Name a for_each group after what its members
  share (`ingress`, `public`, `protected`), or `this` when it is the only group of that type. Key for_each
  collections by the real object name.
- Add variables only for values that genuinely vary. Defaults must equal the reference.
- Adopt pre-existing objects with `import {}` blocks in `imports.tf` plus `lifecycle { prevent_destroy = true }`.
  Import lists name only objects that already exist.
- Write comments only for intent that the code cannot show.
- Add new roots to the loop in `.tekton/ci.yaml`.

## How to

- Repository: add an entry (description, `protected`) to `local.repositories` in
  `terraform/github/repositories.tf`. It is created, not imported. Protected repositories get the PR, merge queue
  and `ci` ruleset; unprotected ones allow direct pushes but block deletion and force-pushes.
