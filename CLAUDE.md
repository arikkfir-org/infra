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
- Add new roots to the loop in `.tekton/ci.yaml`.

## How to

- Repository: add an entry (description, `protected`) to `local.repositories` in
  `terraform/github/repositories.tf`. It is created, not imported. Protected repositories get the PR, merge queue
  and `ci` ruleset; unprotected ones allow direct pushes but block deletion and force-pushes.
- Bucket: add its name and public access prevention (`enforced` unless it must be public) to the map in
  `terraform/gcp/storage.tf`, and its grants to `local.bucket_iam` in `terraform/gcp/iam.tf`.
- Secret: add its ID to the set in `terraform/gcp/secrets.tf`. The External Secrets accessor grant follows
  automatically. The owner adds the value with `gcloud secrets versions add`.
- IAM binding: add the Kubernetes principal (namespace and ServiceAccount) to `local.principals` in
  `terraform/gcp/iam.tf`, then add an entry to the map for its scope: `project_iam`, `bucket_iam` or `images_iam`.
  For another resource type, add an `*_iam_member` resource on that resource.
- Hostname: add it to `local.ingress_hosts` in `terraform/gcp/dns.tf` with its gateway (`protected` or `public`).
