# infra

Terraform for the `arikkfir-org` development hub: the organization's GitHub repositories and rulesets.

Every name, ID, CIDR, role and host comes from the hub reference (`hub/reference.md` in
[arikkfir-org/docs](https://github.com/arikkfir-org/docs)). It is the contract: change it first, then this code.

To build the hub from scratch, follow the
[bootstrap runbook](https://storage.googleapis.com/arikkfir-docs/hub/runbooks/bootstrap.html).

## Layout

| Path | Manages | State prefix |
| --- | --- | --- |
| `terraform/github` | Repositories, vulnerability alerts, default-branch rulesets | `github` |
| `.octomatron.yaml`, `.tekton/ci.yaml` | CI: `terraform fmt` and `validate` on pull requests and in the merge queue | none |

State lives in the GCS bucket `arikkfir-tfstate`, one prefix per root.

## Prerequisites

- Terraform >= 1.14 and the Google Cloud CLI.
- The state bucket, created once by hand:

  ```sh
  gcloud storage buckets create gs://arikkfir-tfstate --project=arikkfir --location=me-west1 \
    --uniform-bucket-level-access --public-access-prevention
  gcloud storage buckets update gs://arikkfir-tfstate --versioning
  ```

- Google credentials for every root (the state backend needs them too): `gcloud auth application-default login` as a
  project owner.
- For `terraform/github`, a token in `GITHUB_TOKEN`: a fine-grained personal access token with resource owner
  `arikkfir-org`, access to all repositories, and the repository permissions **Administration: read and write** and
  **Metadata: read**. The organization must allow fine-grained tokens. A classic token with the `repo` scope also works.

## Apply

Run `terraform -chdir=terraform/github init`, then `plan` and `apply`. The first plan imports the six existing
repositories. The rulesets require the `ci` check, so apply them once Octomatron reports it. Pass the App ID of
`octomatron` with `-var octomatron_app_id=<id>` so that only the App can satisfy the check.
