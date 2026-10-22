# Local entry points: `make check` runs the same checks as CI, `make plan` and `make apply` act on the real infra.
# OVH and HCP Terraform settings come from $(ENV); the GitHub token comes from the gh CLI. Nothing is stored here.
ENV ?= $(HOME)/.config/didelo/ovh-terraform.env
TF = terraform -chdir=terraform
DOCKER = docker run --rm -v "$(CURDIR):/repo" -w /repo

.PHONY: check plan apply

check:
	$(TF) fmt -check -recursive
	$(TF) init -backend=false -input=false >/dev/null
	$(TF) validate
	$(DOCKER) --entrypoint sh ghcr.io/terraform-linters/tflint -c "tflint --init --config /repo/.tflint.hcl >/dev/null && tflint --chdir=terraform --config /repo/.tflint.hcl"
	gitleaks git --redact --no-banner

plan apply:
	set -a && . "$(ENV)" && export GITHUB_TOKEN=$$(gh auth token) && $(TF) init -input=false && $(TF) $@
