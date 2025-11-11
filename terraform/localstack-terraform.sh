#!/bin/bash
# Helper script to run Terraform with LocalStack

# Set fake AWS credentials for LocalStack
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_SESSION_TOKEN="test"
export AWS_DEFAULT_REGION="us-east-1"

# Run terraform with the provided command and local environment
terraform "$@" -var-file=environments/local/terraform.tfvars
