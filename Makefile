.PHONY: help bootstrap-state-backend init plan apply destroy fmt validate bootstrap-init bootstrap-plan bootstrap-apply

# ENV picks the backend + tfvars. Defaults to sandbox.
#   make plan ENV=sandbox
#   make plan ENV=prod
ENV ?= sandbox

TF := terraform
DIR := terraform

help:
	@echo "Terraform AWS template"
	@echo ""
	@echo "State is local by default (./state/<env>.tfstate) — no setup needed."
	@echo ""
	@echo "Optional, only if you switch to S3 state / wire up CI (admin creds):"
	@echo "  make bootstrap-state-backend BUCKET=<b> TABLE=<t>   Create S3 + DynamoDB for state"
	@echo "  make bootstrap-init / bootstrap-plan / bootstrap-apply   OIDC provider + roles + GitHub envs"
	@echo ""
	@echo "Day to day (ENV defaults to sandbox):"
	@echo "  make init  ENV=<env>    terraform init against backends/<env>.hcl"
	@echo "  make plan  ENV=<env>    terraform plan with envs/<env>.tfvars"
	@echo "  make apply ENV=<env>    terraform apply (CI normally does this)"
	@echo "  make destroy ENV=<env>"
	@echo "  make fmt / make validate"

# --- one-time state backend ---------------------------------------------------
bootstrap-state-backend:
	./scripts/bootstrap-state-backend.sh

# --- root stack, per env ------------------------------------------------------
init:
	cd $(DIR) && $(TF) init -backend-config=backends/$(ENV).hcl -reconfigure

plan:
	cd $(DIR) && $(TF) plan -var-file=envs/$(ENV).tfvars -out=tfplan

apply:
	cd $(DIR) && $(TF) apply tfplan

destroy:
	cd $(DIR) && $(TF) destroy -var-file=envs/$(ENV).tfvars

fmt:
	$(TF) fmt -recursive $(DIR)

validate:
	cd $(DIR) && $(TF) validate

# --- bootstrap stack ----------------------------------------------------------
bootstrap-init:
	cd $(DIR)/bootstrap && $(TF) init -backend-config=backends/bootstrap.hcl -reconfigure

bootstrap-plan:
	cd $(DIR)/bootstrap && $(TF) plan -out=tfplan

bootstrap-apply:
	cd $(DIR)/bootstrap && $(TF) apply tfplan
