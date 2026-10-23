# Local entry points: `make check` runs the same checks as CI, `make plan` and `make apply` act on the real infra,
# `make server-diff` previews the server configuration and `make server` applies it (CI does both on main);
# `make server-bootstrap` only creates the CI user, once per fresh server.
# OVH and HCP Terraform settings come from $(ENV); the GitHub token comes from the gh CLI. Nothing is stored here.
ENV ?= $(HOME)/.config/didelo/ovh-terraform.env
TF = terraform -chdir=terraform
PLAYBOOK = cd ansible && ansible-playbook site.yml --diff
DOCKER = docker run --rm -v "$(CURDIR):/repo" -w /repo

.PHONY: check check-monitoring check-secrets plan apply server-diff server server-bootstrap grafana

# Images come from the compose file, so Dependabot bumps the checks along with the stack.
MONITORING = stacks/monitoring
PROMTOOL = $(DOCKER) --entrypoint promtool -w /etc/prometheus -v "$(CURDIR)/$(MONITORING)/prometheus:/etc/prometheus:ro" $$(docker compose -f $(MONITORING)/compose.yaml config --images | grep prom/prometheus)
BLACKBOX = $(DOCKER) -v "$(CURDIR)/$(MONITORING)/blackbox:/config:ro" $$(docker compose -f $(MONITORING)/compose.yaml config --images | grep blackbox)

check-monitoring:
	$(PROMTOOL) check config prometheus.yml
	$(PROMTOOL) test rules rules_test.yml
	$(BLACKBOX) --config.check --config.file=/config/blackbox.yml

# Nothing readable in secrets/: every file there must be SOPS-encrypted.
check-secrets:
	./scripts/check-sops.sh

check: check-monitoring check-secrets
	$(TF) fmt -check -recursive
	$(TF) init -backend=false -input=false >/dev/null
	$(TF) validate
	$(DOCKER) --entrypoint sh ghcr.io/terraform-linters/tflint -c "tflint --init --config /repo/.tflint.hcl >/dev/null && tflint --chdir=terraform --config /repo/.tflint.hcl"
	cd ansible && ansible-lint
	$(DOCKER) rhysd/actionlint:1.7.12
	gitleaks git --redact --no-banner

plan apply:
	set -a && . "$(ENV)" && export GITHUB_TOKEN=$$(gh auth token) && $(TF) init -input=false && $(TF) $@

server-diff:
	$(PLAYBOOK) --check

server:
	$(PLAYBOOK)

server-bootstrap:
	$(PLAYBOOK) --tags ci

# The private Grafana listens on the server's loopback only: this opens it on http://localhost:3000 until Ctrl-C.
grafana:
	ssh -N -L 3000:localhost:3000 didelo-vps
