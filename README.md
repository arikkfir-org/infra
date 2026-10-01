# infra

Terraform for the `arikkfir-org` development hub: the GCP project (network, GKE, Artifact Registry, buckets, Secret
Manager, IAM, DNS), the Argo CD bootstrap, and the organization's GitHub repositories and rulesets.

Every name, ID, CIDR, role and host comes from the hub reference (`hub/reference.md` in
[arikkfir-org/docs](https://github.com/arikkfir-org/docs)). It is the contract: change it first, then this code.

To build the hub from scratch, follow the
[bootstrap runbook](https://github.com/arikkfir-org/docs/blob/main/hub/runbooks/bootstrap.md).

## Layout

| Path | Manages | State prefix |
| --- | --- | --- |
| `terraform/gcp` | APIs, VPC and Cloud NAT, ingress IPs, GKE cluster and node pools, Artifact Registry, buckets, secret containers, IAM, DNS zones and records | `gcp` |
| `terraform/argocd` | Argo CD (bootstrap only) and the `root` Application | `argocd` |
| `terraform/github` | The organization's settings; repositories, their settings, `Default branch` rulesets and `ENG-` autolinks to Linear, Dependabot alerts and Dependabot security updates; team `reviewers` (the pull request reviewer, `push` on every repository) | `github` |
| `.octomaton.yaml`, `.tekton/` | Pipeline `ci` (`Continuous Integration`): unit tests, `terraform fmt`, `validate`, and plans of `gcp` and `github` on pull requests and in the merge queue. Pipeline `apply` (`Apply`): applies `gcp` and `github` on each merge to `main` | none |
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
  changed) and **Metadata: read**, and the organization permissions **Administration: read and write** (the
  organization's settings) and **Members: read and write** (team `reviewers`). The organization must allow
  fine-grained tokens. A classic token with the `repo` and `admin:org` scopes also works.

## Apply order

Apply the roots in this order, each with `make terraform <root>`. It runs `terraform -chdir=terraform/<root> init` and
then `apply`, which shows the plan and asks before it changes anything.

1. `gcp`: the cluster must exist before Argo CD can be installed. The first plan imports the existing `kfirs-com` and
   `kfirfamily-com` zones and must show no changes to them.
2. `argocd`: installs Argo CD, which then syncs everything from `arikkfir-org/delivery`, including Octomaton.
3. `github`: the first plan imports the existing repositories (`imports.tf`). The rulesets require the `Continuous Integration`
   check from the Octomaton App, so apply them once Octomaton reports it.

After that, every merge to `main` applies `gcp` and `github` through Octomaton (hub reference, "Terraform applies"):

- Pull requests and the merge queue plan both roots as `ci-infra/ci-infra-plan`. Its GCP roles only read, but its
  GitHub token also writes contents (GitHub shows merge settings only to such tokens), so code in a pull request can
  push branches and tags to every repository, though not to default branches. The `Continuous Integration` check lists
  the planned changes, deletions and replacements first (a long list is cut short; its log has them all). The merge
  queue takes one pull request at a time, after the previous merge was applied.
- Pipeline `apply` plans both again as `ci-infra/ci-infra-apply` and applies both saved plans in full, deletions and
  replacements included, `gcp` first. The `Apply` check lists the changes.
- By hand, with `make terraform <root>`: `argocd` and a change to the pipelines' own roles or tokens, which they can't
  apply to themselves the first time. The tokens are the Secret Manager secrets `infra-plan-github-pat` and
  `infra-apply-github-pat` (`gcloud secrets versions add`), with the permissions the hub reference lists; both need
  Contents read and write, for the same reason.

## Notes

**GitHub settings outside Terraform.** The provider has no argument for these, so set them by hand in each
repository's Settings → General, new repositories included: under Features, Sponsorships on and Preserve this
repository off. Two more are GitHub's defaults and need nothing unless someone changes them: pull requests open to
all users (Features → Pull requests) and comments on individual commits allowed (Commits). In the `Default branch`
ruleset, likewise, the provider sets neither "Restrict who can dismiss pull request reviews" (off by default) nor
"Require an additional approval for unattributed Copilot pull requests" (on by default). For the organization,
Terraform sets the name, description and billing email, and leaves the rest of the profile and the security defaults
for new repositories as they are: GitHub replaced those defaults with code security configurations.

**Control plane access.** Only the DNS-based endpoint is enabled; both IP-based endpoints are off. Access needs IAM
(`gcloud container clusters get-credentials hub --location=me-west1-a --dns-endpoint`). Nodes still reach the control
plane privately. The endpoint (`*.gke.goog`) serves a publicly trusted Google Trust Services certificate, so the
`argocd` root passes only an access token to the Helm provider. Adding the cluster CA certificate would replace the
system trust store and break TLS verification.

**Firewall.** Terraform adds no firewall rules. The cluster uses Private Service Connect: it has no
`master_ipv4_cidr_block`, and GKE creates the `gke-hub-…-master` rule, which limits the control plane to TCP 443 and
10250, only for clusters that use VPC peering
([automatically created firewall rules](https://cloud.google.com/kubernetes-engine/docs/concepts/firewall-rules)).
Here the API server reaches nodes and Pods through Konnectivity: `konnectivity-agent` Pods open connections to the
control plane on TCP 8132, which default egress allows. Webhook calls, aggregated APIs such as the KEDA metrics server
on 6443, and `logs`/`exec` traffic arrive from those Pods' IPs, and GKE's own `gke-hub-…-all` rule allows Pod-range
traffic on every port
([Konnectivity requirements](https://cloud.google.com/kubernetes-engine/docs/troubleshooting/kubectl)). Webhooks on
9443, 8443 or 10250 therefore need no rule. NetworkPolicy still applies, because Dataplane V2 enforces it: a namespace
with default-deny ingress must allow `kube-system` (konnectivity-agent) to reach its webhook and APIService ports.
To confirm after the first apply, run `gcloud compute firewall-rules list --filter="name~^gke-hub-"`, which should
list no `-master` rule, and `kubectl -n kube-system get deploy konnectivity-agent`, which should find the agent. If a
`-master` rule appears, the cluster uses VPC peering: add an ingress rule from that rule's source range for the
webhook ports.

**Load balancers.** Traefik's `LoadBalancer` Services use backend service-based external passthrough network load
balancers (`loadBalancerClass: networking.gke.io/l4-regional-external`), which bind the reserved `ingress-protected`
and `ingress-public` IPs by name. The HTTP load balancing add-on (GKE Ingress) is disabled; below GKE 1.36 those load
balancers still depend on it, so the cluster's minimum version is 1.36. No GKE Ingress or Gateway resources are used.

**Argo CD handoff.** `helm_release.argocd` uses `ignore_changes = all`. After the first sync, Argo CD manages itself
through the `argocd` Application in `arikkfir-org/delivery`, with the same chart and release name, so it adopts the
bootstrap resources. Argo CD applies manifests directly and never updates the Helm release record, so Terraform
installs Argo CD only when the release is missing and never reverts Argo CD's upgrades. Bootstrap resources that the
self-managed values no longer render are not pruned; delete them once by hand.

**Cost.** The cluster is zonal. The GKE free tier covers the management fee of one zonal cluster per billing account,
but its single control plane is unavailable during control plane upgrades. Maintenance runs on Fridays and Saturdays, 00:00-08:00 UTC. The
`ci` pool scales to zero. It runs on-demand VMs: Spot capacity in the region ran out often enough to preempt most CI
runs. Monitoring collects free system metrics only. Managed Prometheus is on for
`PodMonitoring` resources.
