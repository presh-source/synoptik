# Quick Fix for Backend Initialization Error

## The Error

```
Error: Backend initialization required, please run "terraform init"
Reason: Initial configuration of the requested backend "s3"
```

## Quick Fix

Run these commands:

```bash
cd backend

# Clean everything
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

# Set network fix
export GODEBUG=netdns=go

# Initialize without backend (for LocalStack)
terraform init -reconfigure -backend=false
```

## Why This Happens

Terraform was previously initialized with S3 backend for AWS, but LocalStack uses local state. The `-reconfigure` flag tells Terraform to ignore the previous backend configuration.

## Automated Fix

The deployment script now handles this automatically:

```bash
./scripts/localstack/deploy-full-stack.sh
```

## For AWS Deployment

When deploying to real AWS, use the S3 backend:

```bash
cd backend
terraform init -reconfigure -backend-config=environments/dev/backend.tfvars
```

## Summary

- **LocalStack**: Use `-backend=false` (local state)
- **AWS**: Use `-backend-config=environments/{env}/backend.tfvars` (S3 state)
- **Switching**: Always use `-reconfigure` flag
