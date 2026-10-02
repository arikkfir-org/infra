# CLAUDE.md

## Rules

- Treat the hub reference (`hub/reference.md` in `arikkfir-org/docs`) as the contract for every name, ID, CIDR, role
  and host. If a change needs a new or different value, say so; do not diverge silently.
- Never run `terraform apply`, `make terraform`, `destroy`, `import`, `state …`, `taint`, `force-unlock` or anything
  else that changes real infrastructure or state. Never call GCP or GitHub APIs to inspect live resources. Pipeline
  `apply` applies `gcp` and `github` on each merge to `main`; the owner applies the rest by hand (see README.md).
- Before finishing, run `terraform fmt -recursive` at the repository root, then, in each root under `terraform/`:
  `terraform init -backend=false -input=false && terraform validate`. After changing `.tekton/plan-summary.py`, run
  `python3 -m unittest discover -s tests`. CI (`.tekton/ci.yaml`) runs the same checks and plans `gcp` and `github`.
- Check every argument against the pinned provider schema (`terraform providers schema -json`). Do not use deprecated
  arguments.
- Before adding a resource type, or an argument that calls an API this configuration hasn't called before, check that
  the pipelines can handle it: `ci-infra-plan` must read it and `ci-infra-apply` must change it (their roles are in
  `local.project_iam` in `terraform/gcp/iam.tf` and in the hub reference; `terraform/github` runs on the tokens
  `infra-plan-github-pat` and `infra-apply-github-pat`). Read a role's permissions, not its name. A plan only reads, so
  a missing write permission plans green and fails partway through the apply, with the state half-written. A missing
  role goes in a pull request of its own first, which the owner applies by hand, since the pipelines can't apply
  changes to their own roles (README.md, "Apply order"). A missing token permission is the owner's to add before the
  merge.
- After changing provider versions, run
  `terraform providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64` in that root and keep
  `.terraform.lock.hcl`.

## Conventions

- Keep one root per target (`terraform/<target>`) with state prefix = directory name. Do not add modules.
- Split files by concern: `versions.tf` (terraform block, backend, providers), `variables.tf`, `outputs.tf`,
  `imports.tf`, then one file per area (in `gcp`: `apis`, `network`, `gke`, `registry`, `storage`, `secrets`,
  `iam`, `dns`).
- Name a resource after its object (`hub`, `images`, `gke_nodes`). Name a for_each group after what its members
  share (`ingress`, `public`, `protected`), or `this` when it is the only group of that type. Key for_each
  collections by the real object name.
- Add variables only for values that genuinely vary. Defaults must equal the reference.
- Grant IAM to Kubernetes workloads as `principal://` Workload Identity Federation principals (no Google service
  accounts), at the narrowest scope the reference names (bucket, repository, secret, zone before project).
- Adopt pre-existing objects with `import {}` blocks in `imports.tf` plus `lifecycle { prevent_destroy = true }`.
  Import lists name only objects that already exist.
- Write comments only for intent that the code cannot show.
- Add new roots to the loop in `.tekton/ci.yaml` and to `ROOTS` in the `Makefile`.

## How to

- Repository: add an entry (description, visibility, and in `checks` any required checks beyond `Continuous Integration`
  and `Docs`) to `local.repositories` in `terraform/github/repositories.tf`. It is created, unless it already exists:
  then also add it to the import list in `terraform/github/imports.tf`. Every repository gets the same settings, the
  `Default branch` ruleset (pull request, merge queue, `Continuous Integration` and `Docs` from Octomaton plus its
  `checks` from any source), the `ENG-` autolink to Linear, Dependabot alerts and security updates, and team `reviewers`
  (`terraform/github/teams.tf`) gets `push` on it. Add it to `local.docs_layers` in `terraform/gcp/iam.tf` too, so its
  CI tenant can publish its docs. Tell the owner to set what the provider can't (README.md, Notes).
- Bucket: add its name and public access prevention (`enforced` unless it must be public) to the map in
  `terraform/gcp/storage.tf`, and its grants to `local.bucket_iam` in `terraform/gcp/iam.tf`.
- Secret: add its ID to the set in `terraform/gcp/secrets.tf`. The External Secrets accessor grant follows
  automatically. The owner adds the value with `gcloud secrets versions add`.
- IAM binding: add the Kubernetes principal (namespace and ServiceAccount) to `local.principals` in
  `terraform/gcp/iam.tf`, then add an entry to the map for its scope: `project_iam`, `bucket_iam` or `images_iam`.
  For another resource type, add an `*_iam_member` resource on that resource.
- Hostname: add it to `local.ingress_hosts` in `terraform/gcp/dns.tf` with its gateway (`protected` or `public`).
