#!/bin/sh
# Validates every root, without its backend or credentials (task check).
set -eu
mkdir -p "$TF_PLUGIN_CACHE_DIR"
for root in gcp argocd github keycloak namecheap; do
  echo "==> terraform/${root}"
  terraform -chdir="terraform/${root}" init -backend=false -input=false
  terraform -chdir="terraform/${root}" validate
done
