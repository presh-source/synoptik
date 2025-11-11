# Backend configuration for Terraform state management
# This file defines the S3 backend structure
# Actual values are provided via backend config files in environments/

# The backend block in main.tf will use these configurations:
# terraform init -backend-config=environments/dev/backend.tfvars
