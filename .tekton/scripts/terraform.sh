#!/bin/sh
# Plans root $ROOT into $ROOT.tfplan, and $ROOT.plan.json for the summary, or applies that saved plan, with the
# credentials that credentials.sh read for it.
#
# Usage: terraform.sh plan [terraform plan arguments...]
#        terraform.sh apply
set -eu

c=/var/run/credentials
if [ -f "$c/github-token" ]; then
  GITHUB_TOKEN="$(cat "$c/github-token")"
  export GITHUB_TOKEN
fi
if [ -f "$c/keycloak-secret" ]; then
  KEYCLOAK_CLIENT_SECRET="$(cat "$c/keycloak-secret")"
  export KEYCLOAK_CLIENT_SECRET
fi
# Namecheap's API takes the account's user name as both its user and its API user.
if [ -f "$c/namecheap-api-key" ]; then
  NAMECHEAP_USER_NAME="$(cat "$c/namecheap-api-user")"
  NAMECHEAP_API_USER="$NAMECHEAP_USER_NAME"
  NAMECHEAP_API_KEY="$(cat "$c/namecheap-api-key")"
  export NAMECHEAP_USER_NAME NAMECHEAP_API_USER NAMECHEAP_API_KEY
fi

mkdir -p "$TF_PLUGIN_CACHE_DIR"
tf() { terraform -chdir="terraform/${ROOT}" "$@"; }

case "$1" in
  plan)
    shift
    tf init -input=false
    tf plan -input=false "$@" -out="${ROOT}.tfplan"
    tf show -json "${ROOT}.tfplan" > "${ROOT}.plan.json"
    ;;
  # A saved plan applies only if the state hasn't changed since it was made.
  apply)
    tf apply -input=false -lock-timeout=10m "${ROOT}.tfplan"
    ;;
  *)
    echo "Usage: terraform.sh plan [arguments...] | terraform.sh apply" >&2
    exit 2
    ;;
esac
