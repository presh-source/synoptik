# Local Backend Configuration for LocalStack
# This disables the S3 backend for local development

# Note: When using LocalStack, we don't use remote state
# State will be stored locally in terraform.tfstate

# To initialize with this backend:
# terraform init -backend=false
# or
# terraform init -reconfigure -backend=false
