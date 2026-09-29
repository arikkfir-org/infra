# Terraform for the hub, one root at a time: `make terraform ROOT` initializes terraform/ROOT and
# applies it. Terraform shows the plan and asks before it changes anything. Pass variables as
# TF_VAR_* or in ARGS, e.g. make terraform github ARGS='-var octomaton_app_id=123'.

ROOTS := gcp argocd github
root := $(filter $(ROOTS),$(MAKECMDGOALS))

.PHONY: help terraform $(ROOTS)

help:
	@echo 'Usage: make terraform ROOT [ARGS=...], where ROOT is one of: $(ROOTS)'

terraform:
	$(if $(filter 1,$(words $(root))),,$(error Usage: make terraform ROOT, where ROOT is one of: $(ROOTS)))
	terraform -chdir=terraform/$(root) init -input=false
	terraform -chdir=terraform/$(root) apply $(ARGS)

# The roots are arguments of the terraform target, not targets of their own.
$(ROOTS):
	$(if $(filter terraform,$(MAKECMDGOALS)),@:,$(error Usage: make terraform $@))
