#!/bin/sh
# Reads the credentials that root $ROOT's providers take, as identity $IDENTITY (plan or apply), from Secret Manager
# into /var/run/credentials, a memory volume only the task's steps mount, for terraform.sh to export. Each root reads
# its own and no other's; gcp reads none, since its provider authenticates as the task's ServiceAccount
# (docs/infra/designs/terraform-plan-apply.md).
set -eu
umask 077

read_secret() {
  gcloud secrets versions access latest --secret="$1" --project=arikkfir > "/var/run/credentials/$2"
}

case "$ROOT" in
  github)
    read_secret "infra-${IDENTITY}-github-pat" github-token
    ;;
  keycloak)
    read_secret "infra-${IDENTITY}-keycloak-secret" keycloak-secret
    ;;
  namecheap)
    read_secret infra-namecheap-api-user namecheap-api-user
    read_secret infra-namecheap-api-key namecheap-api-key
    ;;
esac
