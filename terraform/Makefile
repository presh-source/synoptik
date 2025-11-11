# GitHub Digital Twin - Terraform Makefile

.PHONY: help setup-backend-dev setup-backend-staging setup-backend-prod init-dev init-staging init-prod plan-dev plan-staging plan-prod apply-dev apply-staging apply-prod destroy-dev destroy-staging destroy-prod validate format

# Default target
help:
	@echo "GitHub Digital Twin - Terraform Commands"
	@echo ""
	@echo "Backend Setup:"
	@echo "  make setup-backend-dev      - Create S3 bucket and DynamoDB table for dev"
	@echo "  make setup-backend-staging  - Create S3 bucket and DynamoDB table for staging"
	@echo "  make setup-backend-prod     - Create S3 bucket and DynamoDB table for prod"
	@echo ""
	@echo "Terraform Operations:"
	@echo "  make init-dev               - Initialize Terraform for dev environment"
	@echo "  make init-staging           - Initialize Terraform for staging environment"
	@echo "  make init-prod              - Initialize Terraform for prod environment"
	@echo ""
	@echo "  make plan-dev               - Plan changes for dev environment"
	@echo "  make plan-staging           - Plan changes for staging environment"
	@echo "  make plan-prod              - Plan changes for prod environment"
	@echo ""
	@echo "  make apply-dev              - Apply changes for dev environment"
	@echo "  make apply-staging          - Apply changes for staging environment"
	@echo "  make apply-prod             - Apply changes for prod environment"
	@echo ""
	@echo "  make destroy-dev            - Destroy dev environment (WARNING: destructive)"
	@echo "  make destroy-staging        - Destroy staging environment (WARNING: destructive)"
	@echo "  make destroy-prod           - Destroy prod environment (WARNING: destructive)"
	@echo ""
	@echo "Utilities:"
	@echo "  make validate               - Validate Terraform configuration"
	@echo "  make format                 - Format Terraform files"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Set GitHub token: export TF_VAR_github_token='your_token_here'"
	@echo "  - Configure AWS CLI: aws configure"

# Backend setup
setup-backend-dev:
	@./scripts/setup-backend.sh dev

setup-backend-staging:
	@./scripts/setup-backend.sh staging

setup-backend-prod:
	@./scripts/setup-backend.sh prod

# Initialize Terraform
init-dev:
	terraform init -backend-config=environments/dev/backend.tfvars

init-staging:
	terraform init -reconfigure -backend-config=environments/staging/backend.tfvars

init-prod:
	terraform init -reconfigure -backend-config=environments/prod/backend.tfvars

# Plan changes
plan-dev:
	terraform plan -var-file=environments/dev/terraform.tfvars

plan-staging:
	terraform plan -var-file=environments/staging/terraform.tfvars

plan-prod:
	terraform plan -var-file=environments/prod/terraform.tfvars

# Apply changes
apply-dev:
	terraform apply -var-file=environments/dev/terraform.tfvars

apply-staging:
	terraform apply -var-file=environments/staging/terraform.tfvars

apply-prod:
	terraform apply -var-file=environments/prod/terraform.tfvars

# Destroy infrastructure
destroy-dev:
	@echo "WARNING: This will destroy all dev infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	terraform destroy -var-file=environments/dev/terraform.tfvars

destroy-staging:
	@echo "WARNING: This will destroy all staging infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	terraform destroy -var-file=environments/staging/terraform.tfvars

destroy-prod:
	@echo "WARNING: This will destroy all production infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	terraform destroy -var-file=environments/prod/terraform.tfvars

# Utilities
validate:
	terraform validate

format:
	terraform fmt -recursive
