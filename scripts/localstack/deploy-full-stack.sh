#!/bin/bash

# Complete LocalStack Deployment Script for Synoptik
# This script deploys the entire stack to LocalStack

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
LOCALSTACK_ENDPOINT="http://localhost:4566"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Synoptik - Complete LocalStack Deployment         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Step 1: Prerequisites Check
# ============================================================================

echo -e "${CYAN}[1/6] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform installed${NC}"

if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗ Node.js/npm is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Node.js/npm installed${NC}"

if ! command -v awslocal &> /dev/null; then
    echo -e "${YELLOW}Installing awscli-local...${NC}"
    pip install awscli-local
fi
echo -e "${GREEN}✓ awscli-local installed${NC}"

echo ""

# ============================================================================
# Step 2: Start LocalStack
# ============================================================================

echo -e "${CYAN}[2/6] Starting LocalStack...${NC}"

cd "$SCRIPT_DIR"

# Clean up previous state
docker-compose -f docker-compose.localstack.yml down -v
rm -rf localstack-data

# Check if LocalStack is already running
if docker ps | grep -q synoptik-localstack; then
    echo -e "${YELLOW}LocalStack is already running${NC}"
else
    docker-compose -f docker-compose.localstack.yml up -d
    echo -e "${GREEN}✓ LocalStack started${NC}"
fi

# Wait for LocalStack to be ready
echo -e "${YELLOW}Waiting for LocalStack to be ready...${NC}"
RETRY_COUNT=0
MAX_RETRIES=60

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s "${LOCALSTACK_ENDPOINT}/_localstack/health" > /dev/null 2>&1; then
        RUNNING_SERVICES=$(curl -s "${LOCALSTACK_ENDPOINT}/_localstack/health" | grep -o '"running"' | wc -l)
        if [ "$RUNNING_SERVICES" -gt 5 ]; then
            echo -e "${GREEN}✓ LocalStack is ready (${RUNNING_SERVICES} services running)${NC}"
            break
        fi
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}✗ LocalStack failed to start${NC}"
        docker-compose -f docker-compose.localstack.yml logs --tail=50
        exit 1
    fi
    
    if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
        echo -e "${YELLOW}  Still waiting... (${RETRY_COUNT}s)${NC}"
    fi
    
    sleep 1
done

echo ""

# ============================================================================
# Step 3: Deploy Infrastructure with Terraform
# ============================================================================

echo -e "${CYAN}[3/6] Deploying infrastructure with Terraform...${NC}"

cd "$PROJECT_ROOT/backend"

# Set environment variables
export USE_LOCALSTACK=true
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export TF_VAR_github_token="test_token_for_localstack"
export TF_VAR_sentry_dsn_frontend="https://test-frontend@sentry.io/123"
export TF_VAR_sentry_dsn_backend="https://test-backend@sentry.io/456"
export TF_VAR_app_version="1.0.0-localstack"

# Clean old initialization and state files
echo -e "${YELLOW}Cleaning old Terraform state...${NC}"
rm -rf .terraform*
if [ -d ".terraform" ]; then
    rm -rf .terraform .terraform.lock.hcl
fi
if [ -f "terraform.tfstate" ]; then
    rm -f terraform.tfstate terraform.tfstate.backup
fi

# Initialize Terraform without backend
echo -e "${YELLOW}Initializing Terraform (without S3 backend for LocalStack)...${NC}"

# Set GODEBUG to force IPv4 (fixes registry connectivity issues)
export GODEBUG=netdns=go

# Initialize with -reconfigure to override backend configuration
for i in {1..3}; do
  if terraform init -reconfigure -backend=false; then
    break
  fi
  if [ $i -lt 3 ]; then
    echo -e "${YELLOW}Terraform initialization failed. Retrying in 5 seconds...${NC}"
    sleep 5
  else
    echo -e "${RED}✗ Terraform initialization failed after 3 attempts.${NC}"
    echo -e "${YELLOW}This might be a network connectivity issue.${NC}"
    echo -e "${YELLOW}Try running: export GODEBUG=netdns=go${NC}"
    echo -e "${YELLOW}See TERRAFORM_NETWORK_FIX.md for solutions${NC}"
    exit 1
  fi
done

echo -e "${GREEN}✓ Terraform initialized${NC}"

# Validate configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan deployment
echo -e "${YELLOW}Planning infrastructure deployment...${NC}"
terraform plan \
  -var-file=environments/local/terraform.tfvars \
  -var='localstack_config={enabled="true",endpoint="http://localhost:4566"}' \
  -out=tfplan

# Apply deployment
echo -e "${YELLOW}Applying infrastructure deployment...${NC}"
terraform apply -auto-approve tfplan

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# ============================================================================
# Step 4: Verify Infrastructure
# ============================================================================

echo -e "${CYAN}[4/6] Verifying infrastructure...${NC}"

# Check S3 buckets
echo -e "${YELLOW}Checking S3 buckets...${NC}"
awslocal s3 ls
echo -e "${GREEN}✓ S3 buckets created${NC}"

# Check Lambda functions
echo -e "${YELLOW}Checking Lambda functions...${NC}"
awslocal lambda list-functions --query 'Functions[].FunctionName' --output table
echo -e "${GREEN}✓ Lambda functions deployed${NC}"

# Check API Gateway
echo -e "${YELLOW}Checking API Gateway...${NC}"
awslocal apigateway get-rest-apis --query 'items[].name' --output table
echo -e "${GREEN}✓ API Gateway created${NC}"

# Check Secrets Manager
echo -e "${YELLOW}Checking Secrets Manager...${NC}"
awslocal secretsmanager list-secrets --query 'SecretList[].Name' --output table
echo -e "${GREEN}✓ Secrets created${NC}"

echo ""

# ============================================================================
# Step 5: Build and Deploy Dashboard
# ============================================================================

cd "$PROJECT_ROOT/frontend"

# Create .env.local for LocalStack
echo -e "${YELLOW}Creating dashboard environment configuration...${NC}"
cat > .env.local << EOF
VITE_API_URL=http://localhost:4566/restapis/local-api-id/local/_user_request_
VITE_SENTRY_DSN=https://test-frontend@sentry.io/123
VITE_APP_VERSION=1.0.0-localstack
EOF

# Install dependencies
echo -e "${YELLOW}Installing dashboard dependencies...${NC}"
npm install --legacy-peer-deps --silent

# Build dashboard
echo -e "${YELLOW}Building dashboard...${NC}"
npm run build

# Get S3 bucket name from Terraform
cd "$PROJECT_ROOT/backend"
DASHBOARD_BUCKET=$(terraform output -raw dashboard_bucket_name 2>/dev/null || echo "synoptik-dashboard-local")

# Deploy to LocalStack S3
cd "$PROJECT_ROOT/frontend"
echo -e "${YELLOW}Deploying dashboard to S3...${NC}"

# Create bucket if it doesn't exist
awslocal s3 mb s3://${DASHBOARD_BUCKET} 2>/dev/null || true

# Configure bucket for website hosting
awslocal s3 website s3://${DASHBOARD_BUCKET} \
  --index-document index.html \
  --error-document index.html

# Make bucket publicly readable (LocalStack only)
awslocal s3api put-bucket-policy \
  --bucket ${DASHBOARD_BUCKET} \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::'${DASHBOARD_BUCKET}'/*"
    }]
  }'

# Upload files
awslocal s3 sync dist/ s3://${DASHBOARD_BUCKET}/ --delete

echo -e "${GREEN}✓ Dashboard deployed${NC}"
echo ""

# ============================================================================
# Step 6: Display Access Information
# ============================================================================

echo -e "${CYAN}[6/6] Deployment complete!${NC}"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Deployment Successful! 🚀                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📊 Dashboard URLs:${NC}"
echo -e "  S3 Direct:   ${GREEN}http://localhost:4566/${DASHBOARD_BUCKET}/index.html${NC}"
echo -e "  S3 Website:  ${GREEN}http://${DASHBOARD_BUCKET}.s3-website.localhost.localstack.cloud:4566${NC}"
echo ""

echo -e "${BLUE}🔌 API Endpoints:${NC}"
API_ID=$(awslocal apigateway get-rest-apis --query 'items[0].id' --output text 2>/dev/null || echo "unknown")
echo -e "  Base URL:    ${GREEN}http://localhost:4566/restapis/${API_ID}/local/_user_request_${NC}"
echo -e "  Pipeline:    ${GREEN}http://localhost:4566/restapis/${API_ID}/local/_user_request_/pipeline-status${NC}"
echo -e "  Metrics:     ${GREEN}http://localhost:4566/restapis/${API_ID}/local/_user_request_/metrics/realtime${NC}"
echo ""

echo -e "${BLUE}🗄️  Infrastructure:${NC}"
echo -e "  LocalStack:  ${GREEN}http://localhost:4566${NC}"
echo -e "  Health:      ${GREEN}http://localhost:4566/_localstack/health${NC}"
echo ""

echo -e "${BLUE}📦 Resources Created:${NC}"
echo -e "  S3 Buckets:       $(awslocal s3 ls | wc -l | tr -d ' ')"
echo -e "  Lambda Functions: $(awslocal lambda list-functions --query 'length(Functions)' --output text)"
echo -e "  API Gateways:     $(awslocal apigateway get-rest-apis --query 'length(items)' --output text)"
echo -e "  Secrets:          $(awslocal secretsmanager list-secrets --query 'length(SecretList)' --output text)"
echo ""

echo -e "${BLUE}🛠️  Useful Commands:${NC}"
echo -e "  View logs:        ${YELLOW}docker-compose -f scripts/localstack/docker-compose.localstack.yml logs -f${NC}"
echo -e "  List S3:          ${YELLOW}awslocal s3 ls${NC}"
echo -e "  List Lambda:      ${YELLOW}awslocal lambda list-functions${NC}"
echo -e "  Stop LocalStack:  ${YELLOW}docker-compose -f scripts/localstack/docker-compose.localstack.yml down${NC}"
echo ""

echo -e "${YELLOW}💡 Tip: The dashboard may take a few seconds to load initially${NC}"
echo ""
