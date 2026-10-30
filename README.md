# infra

Terraform for the `arikkfir-org` development hub: the GCP project (network, GKE, Artifact Registry, buckets, Secret
Manager, IAM, DNS), the Argo CD bootstrap, the organization's GitHub repositories and rulesets, Keycloak's
configuration, and the nameservers of the domains registered at Namecheap.

Every name, ID, CIDR, role and host this code creates is documented in its root's page,
`https://docs.dev.kfirs.com/infra/terraform/<root>.md`, which other repositories link: a change to one starts here, and
updates that page in the same pull request. Names it takes from another repository, such as namespaces,
ServiceAccounts and hosts' backends, come from that repository's pages.

What each root provisions, and why: [gcp](docs/infra/terraform/gcp.md), [argocd](docs/infra/terraform/argocd.md),
[github](docs/infra/terraform/github.md), [keycloak](docs/infra/terraform/keycloak.md) and
[namecheap](docs/infra/terraform/namecheap.md). How pull requests plan and
merges apply: [Terraform plan and apply](docs/infra/designs/terraform-plan-apply.md). To build the hub from scratch,
follow the [bootstrap runbook](docs/infra/runbooks/bootstrap.md). Every page is also on the docs site, under
`https://docs.dev.kfirs.com/infra/`.

## Layout

| Path | Manages | State prefix |
| --- | --- | --- |
| [`terraform/gcp`](docs/infra/terraform/gcp.md) | APIs, VPC and Cloud NAT, ingress IPs, GKE cluster and node pools, Artifact Registry, buckets, secret containers, IAM, DNS zones and records | `gcp` |
| [`terraform/argocd`](docs/infra/terraform/argocd.md) | Argo CD (bootstrap only) and the `root` Application | `argocd` |
| [`terraform/github`](docs/infra/terraform/github.md) | The organization's settings; repositories, their settings, `Default branch` rulesets and `ENG-` autolinks to Linear, Dependabot alerts and Dependabot security updates; team `reviewers` (the pull request reviewer, `push` on every repository) | `github` |
| [`terraform/keycloak`](docs/infra/terraform/keycloak.md) | Keycloak's realm `hub` (its login page and flows, the Google identity provider, clients `hub` and `cobranch` (Cobranch's demo), the people who may sign in and groups `admins` and `fin-e2e`, client `fin-e2e` for Fin's test users and client `fin-local` for Fin's local development) and, in realm `master`, the same Google sign-in for the admins and the pipelines' clients; it writes the clients' generated secrets to Secret Manager | `keycloak` |
| [`terraform/namecheap`](docs/infra/terraform/namecheap.md) | The nameservers of `octomaton.dev`, `cobranch.dev` and `cobranch.app` at Namecheap, each set to its Cloud DNS zone's (root `gcp`) | `namecheap` |
| `.octomaton.yaml`, `.tekton/` | Pipeline `ci` (`Continuous Integration`): unit tests, `terraform fmt`, `validate`, and plans of `gcp`, `github`, `keycloak` and `namecheap`, a task each, all at once, on pull requests and in the merge queue. Pipeline `apply` (`Apply`): applies `gcp` and `github` at once and `keycloak` and `namecheap` after `gcp`, on each merge to `main`. Each task is also its own check, such as `Continuous Integration / gcp`. The PipelineRuns reference their Tasks and StepActions in files beside them, whose scripts are in `.tekton/scripts/` | none |
| `tests/` | Unit tests of `.tekton/plan-summary.py` (`python3 -m unittest discover -s tests`), which `ci` runs | none |
| `Makefile` | `make terraform <root>`: `init`, then `apply` of one root | none |

State lives in the GCS bucket `arikkfir-devops`, one prefix per root.

## Prerequisites

- Terraform >= 1.14 and the Google Cloud CLI.
- The state bucket `arikkfir-devops` (versioned). If it doesn't exist yet, create it once:

  ```sh
  gcloud storage buckets create gs://arikkfir-devops --project=arikkfir --location=me-west1 \
    --uniform-bucket-level-access --public-access-prevention
  gcloud storage buckets update gs://arikkfir-devops --versioning
  ```

- Google credentials for every root (the state backend needs them too): `gcloud auth application-default login` as a
  project owner. The `argocd` root reaches the cluster through its DNS endpoint, which needs the
  `container.clusters.connect` permission (owners have it).
- For `terraform/github`, a token in `GITHUB_TOKEN`: a fine-grained personal access token with resource owner
  `arikkfir-org`, access to all repositories, the repository permissions **Administration: read and write**,
  **Contents: read and write** (GitHub shows merge settings only to tokens with it; without it every plan shows them
  changed), **Pull requests: read and write** (the repositories' labels) and **Metadata: read**, and the organization
  permissions **Administration: read and write** (the
  organization's settings) and **Members: read and write** (team `reviewers`). The organization must allow
  fine-grained tokens. A classic token with the `repo` and `admin:org` scopes also works.
- For `terraform/keycloak`, a service account in Keycloak's realm `master` in `KEYCLOAK_CLIENT_ID` and
  `KEYCLOAK_CLIENT_SECRET`, and Keycloak's admin API: from a workstation, `kubectl -n keycloak port-forward
  svc/keycloak-service 8080` and `ARGS="-var keycloak_url=http://localhost:8080"`.
- For `terraform/namecheap`, the Namecheap account's user name in `NAMECHEAP_USER_NAME` and `NAMECHEAP_API_USER` and
  its API key in `NAMECHEAP_API_KEY`. Namecheap answers only the IPs on the account's allow-list, address `egress`,
  so it runs only in the cluster ([root namecheap](docs/infra/terraform/namecheap.md#running-it-by-hand)).

## Apply order

Apply the roots in this order, each with `make terraform <root>`. It runs `terraform -chdir=terraform/<root> init` and
then `apply`, which shows the plan and asks before it changes anything.

1. `gcp`: the cluster must exist before Argo CD can be installed. The first plan imports the existing `kfirs-com` and
   `kfirfamily-com` zones and must show no changes to them.
2. `argocd`: installs Argo CD, which then syncs everything from `arikkfir-org/delivery`, including Octomaton.
3. `github`: the first plan imports the existing repositories (`imports.tf`). The rulesets require the
   `Continuous Integration`, `Docs` and `Linear` checks from the Octomaton App, so apply them once Octomaton reports all
   three.
4. `keycloak`, once Keycloak runs (`delivery`): the first apply runs as the bootstrap admin (`KEYCLOAK_CLIENT_ID` is
   `bootstrap-admin`, `KEYCLOAK_CLIENT_SECRET` the Secret Manager secret `keycloak-bootstrap-admin`). It creates the
   pipelines' own clients, `terraform-plan` and `terraform-apply`, and writes their secrets.
5. `namecheap`, through the pipelines only, once root `gcp`'s zones and address `egress` exist, the owner has turned on
   Namecheap's API access, allow-listed `egress` and added the values of `infra-namecheap-api-user` and
   `infra-namecheap-api-key`. Before its first plan, the owner runs `terraform -chdir=terraform/namecheap init` once,
   which creates its empty state: `ci-infra-plan` can only read the state bucket. Its first plan imports the domains.

After that, every merge to `main` applies `gcp`, `github`, `keycloak` and `namecheap` through Octomaton, and every pull
request plans them ([Terraform plan and apply](docs/infra/designs/terraform-plan-apply.md)). By hand, with
`make terraform <root>`: `argocd`, and a change to the pipelines' own roles or tokens, which they can't apply to
themselves the first time. The tokens are the Secret Manager secrets `infra-plan-github-pat` and
`infra-apply-github-pat` (`gcloud secrets versions add`), with the permissions that design lists; both need Contents
read and write.

## Notes

The cluster's control plane access, firewall, load balancers, node pools and cost: [root gcp](docs/infra/terraform/gcp.md).
Argo CD's handoff to itself: [root argocd](docs/infra/terraform/argocd.md#the-handoff). The GitHub settings the
provider can't set, which the owner sets by hand in every repository, new ones included:
[root github](docs/infra/terraform/github.md#set-outside-terraform).
