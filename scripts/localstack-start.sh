#!/bin/bash

# Quick Start Script for LocalStack Development Environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Synoptik - LocalStack Quick Start              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    echo -e "  Install from: https://www.docker.com/products/docker-desktop"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform is not installed${NC}"
    echo -e "  Install with: brew install terraform"
    exit 1
fi
echo -e "${GREEN}✓ Terraform installed${NC}"

if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗ Node.js/npm is not installed${NC}"
    echo -e "  Install from: https://nodejs.org/"
    exit 1
fi
echo -e "${GREEN}✓ Node.js/npm installed${NC}"

# Install awslocal if not present
if ! command -v awslocal &> /dev/null; then
    echo -e "${YELLOW}Installing awscli-local...${NC}"
    pip install awscli-local
fi
echo -e "${GREEN}✓ awscli-local installed${NC}"
echo ""

# Start LocalStack
echo -e "${YELLOW}Starting LocalStack...${NC}"
docker-compose -f docker-compose.localstack.yml up -d

# Wait for LocalStack to be ready
echo -e "${YELLOW}Waiting for LocalStack to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ LocalStack is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ LocalStack failed to start${NC}"
        exit 1
    fi
    sleep 1
done
echo ""

# Deploy infrastructure
echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
cd terraform

export USE_LOCALSTACK=true
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export TF_VAR_github_token="test_token_for_localstack"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    terraform init
fi

# Apply Terraform configuration
terraform apply \
  -var-file=environments/local/terraform.tfvars \
  -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}" \
  -auto-approve

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
cd ..
echo ""

# Deploy dashboard
echo -e "${YELLOW}Deploying dashboard...${NC}"
cd dashboard
./deploy-localstack.sh
cd ..
echo ""

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Complete! 🚀                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Access Points:${NC}"
echo -e "  Dashboard:   ${GREEN}http://localhost:4566/synoptik-dashboard-local/index.html${NC}"
echo -e "  LocalStack:  ${GREEN}http://localhost:4566${NC}"
echo -e "  Health:      ${GREEN}http://localhost:4566/_localstack/health${NC}"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo -e "  View logs:        ${YELLOW}docker-compose -f docker-compose.localstack.yml logs -f${NC}"
echo -e "  List S3 buckets:  ${YELLOW}awslocal s3 ls${NC}"
echo -e "  List DynamoDB:    ${YELLOW}awslocal dynamodb list-tables${NC}"
echo -e "  Stop LocalStack:  ${YELLOW}docker-compose -f docker-compose.localstack.yml down${NC}"
echo ""
echo -e "${YELLOW}For more information, see LOCALSTACK_SETUP.md${NC}"
echo ""
