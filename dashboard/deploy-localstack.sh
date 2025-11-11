#!/bin/bash

# Dashboard LocalStack Deployment Script
# This script builds the React application and deploys it to LocalStack S3/CloudFront

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOCALSTACK_ENDPOINT=${LOCALSTACK_ENDPOINT:-http://localhost:4566}
BUCKET_NAME="${var.project_name}-dashboard-local"
DISTRIBUTION_ID="E1234567890ABC"  # LocalStack uses fake IDs

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        ${var.project_name} - LocalStack Deployment                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if LocalStack is running
echo -e "${YELLOW}Checking LocalStack status...${NC}"
if ! curl -s "${LOCALSTACK_ENDPOINT}/_localstack/health" > /dev/null 2>&1; then
  echo -e "${RED}LocalStack is not running!${NC}"
  echo -e "${YELLOW}Start LocalStack with: localstack start${NC}"
  exit 1
fi
echo -e "${GREEN}✓ LocalStack is running${NC}"
echo ""

# Check if required tools are installed
command -v npm >/dev/null 2>&1 || { echo -e "${RED}npm is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v awslocal >/dev/null 2>&1 || { 
  echo -e "${YELLOW}awslocal wrapper not found. Installing...${NC}"
  pip install awscli-local
}

# Create .env.local for LocalStack API endpoint
echo -e "${YELLOW}Configuring environment...${NC}"
cat > .env.local << EOF
VITE_API_URL=${DASHBOARD_API_URL:-http://localhost:4566/restapis/local-api-id/local/_user_request_}
EOF
echo -e "${GREEN}✓ Created .env.local${NC}"
echo ""

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
npm install --legacy-peer-deps --silent
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Build the application
echo -e "${YELLOW}Building application...${NC}"
npm run build
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Create S3 bucket in LocalStack
echo -e "${YELLOW}Setting up S3 bucket: ${BUCKET_NAME}${NC}"
awslocal s3 mb s3://${BUCKET_NAME} 2>/dev/null || echo "Bucket already exists"

# Configure bucket for website hosting
awslocal s3 website s3://${BUCKET_NAME} \
  --index-document index.html \
  --error-document index.html

# Make bucket publicly readable (LocalStack only)
awslocal s3api put-bucket-policy \
  --bucket ${BUCKET_NAME} \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::'${BUCKET_NAME}'/*"
    }]
  }'

echo -e "${GREEN}✓ S3 bucket configured${NC}"
echo ""

# Upload to S3
echo -e "${YELLOW}Uploading files to LocalStack S3...${NC}"
awslocal s3 sync dist/ s3://${BUCKET_NAME}/ --delete
echo -e "${GREEN}✓ Files uploaded${NC}"
echo ""

# Get the S3 website endpoint
WEBSITE_URL="http://${BUCKET_NAME}.s3-website.localhost.localstack.cloud:4566"

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Deployment Complete! 🚀                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Dashboard URLs:${NC}"
echo -e "  S3 Website:  ${GREEN}${WEBSITE_URL}${NC}"
echo -e "  S3 Direct:   ${GREEN}${LOCALSTACK_ENDPOINT}/${BUCKET_NAME}/index.html${NC}"
echo ""
echo -e "${BLUE}LocalStack Services:${NC}"
echo -e "  Health:      ${GREEN}${LOCALSTACK_ENDPOINT}/_localstack/health${NC}"
echo -e "  S3 Buckets:  ${GREEN}awslocal s3 ls${NC}"
echo ""
echo -e "${YELLOW}Note: Make sure your backend API is also running in LocalStack${NC}"
echo -e "${YELLOW}or update VITE_API_URL in .env.local to point to your API${NC}"
echo ""
