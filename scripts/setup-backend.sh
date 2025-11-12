#!/bin/bash
# Setup script for Terraform S3 backend and DynamoDB state locking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if environment is provided
if [ -z "$1" ]; then
    print_error "Usage: ./setup-backend.sh <environment>"
    print_info "Example: ./setup-backend.sh dev"
    exit 1
fi

ENV=$1
REGION="us-east-1"
PROJECT_NAME="synoptik"
BUCKET_NAME="${ENV}-${PROJECT_NAME}-terraform-state"
DYNAMODB_TABLE="${ENV}-${PROJECT_NAME}-terraform-locks"

print_info "Setting up Terraform backend for environment: ${ENV}"
print_info "Region: ${REGION}"
print_info "S3 Bucket: ${BUCKET_NAME}"
print_info "DynamoDB Table: ${DYNAMODB_TABLE}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured. Run 'aws configure' first."
    exit 1
fi

print_info "AWS credentials verified"

# Create S3 bucket
print_info "Creating S3 bucket: ${BUCKET_NAME}"
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    print_warning "S3 bucket already exists: ${BUCKET_NAME}"
else
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${REGION}"
    print_info "S3 bucket created successfully"
fi

# Enable versioning
print_info "Enabling versioning on S3 bucket"
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

# Enable encryption
print_info "Enabling encryption on S3 bucket"
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{ "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }] }'

# Block public access
print_info "Blocking public access on S3 bucket"
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table
print_info "Creating DynamoDB table: ${DYNAMODB_TABLE}"
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" &> /dev/null; then
    print_warning "DynamoDB table already exists: ${DYNAMODB_TABLE}"
else
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PROVISIONED \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --deletion-protection-enabled \
        --region "${REGION}" \
        --tags Key=Environment,Value="${ENV}" Key=Project,Value="${PROJECT_NAME}"
    
    print_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${REGION}"
    print_info "DynamoDB table created successfully"
fi

print_info ""
print_info "Backend setup complete for environment: ${ENV}"
print_info ""
print_info "Next steps:"
print_info "1. Set your GitHub token: export TF_VAR_github_token='your_token_here'"
print_info "2. Initialize Terraform: terraform init -backend-config=environments/${ENV}/backend.tfvars"
print_info "3. Plan deployment: terraform plan -var-file=environments/${ENV}/terraform.tfvars"
print_info "4. Apply deployment: terraform apply -var-file=environments/${ENV}/terraform.tfvars"
