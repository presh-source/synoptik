#!/bin/bash

# Dashboard Deployment Script
# This script builds the React application and deploys it to S3/CloudFront

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}

echo -e "${GREEN}Starting dashboard deployment for environment: ${ENVIRONMENT}${NC}"

# Check if required tools are installed
command -v npm >/dev/null 2>&1 || { echo -e "${RED}npm is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }

# Get S3 bucket name and CloudFront distribution ID from Terraform outputs
echo -e "${YELLOW}Fetching deployment targets from Terraform...${NC}"
cd ../terraform

BUCKET_NAME=$(terraform output -raw dashboard_bucket_name 2>/dev/null || echo "")
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

if [ -z "$BUCKET_NAME" ]; then
  echo -e "${RED}Could not find S3 bucket name. Make sure Terraform has been applied.${NC}"
  exit 1
fi

if [ -z "$DISTRIBUTION_ID" ]; then
  echo -e "${YELLOW}Warning: Could not find CloudFront distribution ID. Cache invalidation will be skipped.${NC}"
fi

cd ../dashboard

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
npm install --legacy-peer-deps

# Build the application
echo -e "${YELLOW}Building application...${NC}"
npm run build

# Upload to S3
echo -e "${YELLOW}Uploading to S3 bucket: ${BUCKET_NAME}${NC}"
aws s3 sync dist/ s3://${BUCKET_NAME}/ \
  --region ${AWS_REGION} \
  --delete \
  --cache-control "public, max-age=31536000, immutable" \
  --exclude "index.html"

# Upload index.html with no-cache
aws s3 cp dist/index.html s3://${BUCKET_NAME}/index.html \
  --region ${AWS_REGION} \
  --cache-control "no-cache, no-store, must-revalidate" \
  --metadata-directive REPLACE

# Invalidate CloudFront cache
if [ -n "$DISTRIBUTION_ID" ]; then
  echo -e "${YELLOW}Invalidating CloudFront cache...${NC}"
  aws cloudfront create-invalidation \
    --distribution-id ${DISTRIBUTION_ID} \
    --paths "/*" \
    --region ${AWS_REGION}
fi

# Get the dashboard URL
DASHBOARD_URL=$(cd ../terraform && terraform output -raw dashboard_url 2>/dev/null || echo "")

echo -e "${GREEN}Deployment complete!${NC}"
if [ -n "$DASHBOARD_URL" ]; then
  echo -e "${GREEN}Dashboard URL: ${DASHBOARD_URL}${NC}"
fi
