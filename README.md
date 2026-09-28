# infra

Terraform for the `arikkfir-org` development hub: the GCP project (network, GKE, Artifact Registry, buckets, Secret
Manager, IAM, DNS), the Argo CD bootstrap, and the organization's GitHub repositories and rulesets.

Every name, ID, CIDR, role and host comes from the hub reference (`hub/reference.md` in
[arikkfir-org/docs](https://github.com/arikkfir-org/docs)). It is the contract: change it first, then this code.

To build the hub from scratch, follow the
[bootstrap runbook](https://storage.googleapis.com/arikkfir-docs/hub/runbooks/bootstrap.html).

## Layout

| Path | Manages | State prefix |
| --- | --- | --- |
| `terraform/gcp` | APIs, VPC and Cloud NAT, ingress IPs, GKE cluster and node pools, Artifact Registry, buckets, secret containers, Workload Identity Federation, IAM, DNS zones and records | `gcp` |
| `terraform/argocd` | Argo CD (bootstrap only) and the `root` Application | `argocd` |
| `terraform/github` | Repositories, vulnerability alerts, default-branch rulesets | `github` |
| `.switchboard.yaml`, `.tekton/ci.yaml` | CI: `terraform fmt` and `validate` on pull requests and in the merge queue | none |

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
  project owner. The `argocd` root reaches the cluster through its DNS endpoint, which needs the
  `container.clusters.connect` permission (owners have it).
- For `terraform/github`, a token in `GITHUB_TOKEN`: a fine-grained personal access token with resource owner
  `arikkfir-org`, access to all repositories, and the repository permissions **Administration: read and write** and
  **Metadata: read**. The organization must allow fine-grained tokens. A classic token with the `repo` scope also works.

## Apply order

Apply the roots in this order, each with `terraform -chdir=terraform/<root> init` and then `plan` and `apply`:

1. `gcp`: the cluster must exist before Argo CD can be installed. The first plan imports the existing `kfirs-com` and
   `kfirfamily-com` zones and must show no changes to them.
2. `argocd`: installs Argo CD, which then syncs everything from `arikkfir-org/delivery`, including Switchboard.
3. `github`: the first plan imports the six existing repositories. The rulesets require the `ci` check, so apply them
   once Switchboard reports it. Pass the App ID of `arikkfir-switchboard` with `-var switchboard_app_id=<id>` so that
   only the App can satisfy the check.

## Notes

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

**Load balancers.** The HTTP load balancing add-on stays enabled (GKE's default): Traefik's `LoadBalancer` Services
use backend service-based external passthrough network load balancers (`cloud.google.com/l4-rbs`), which bind the
reserved `ingress-protected` and `ingress-public` IPs by name and, below GKE 1.36, require that add-on. No GKE
Ingress or Gateway resources are used.

**Argo CD handoff.** `helm_release.argocd` uses `ignore_changes = all`. After the first sync, Argo CD manages itself
through the `argocd` Application in `arikkfir-org/delivery`, with the same chart and release name, so it adopts the
bootstrap resources. Argo CD applies manifests directly and never updates the Helm release record, so Terraform
installs Argo CD only when the release is missing and never reverts Argo CD's upgrades. Bootstrap resources that the
self-managed values no longer render are not pruned; delete them once by hand.

**Cost.** The cluster is zonal. The GKE free tier covers the management fee of one zonal cluster per billing account,
but its single control plane is unavailable during control plane upgrades. Maintenance runs on Fridays and Saturdays, 00:00-08:00 UTC. The
Spot `ci` pool scales to zero. Monitoring collects free system metrics only. Managed Prometheus is on for
`PodMonitoring` resources.
