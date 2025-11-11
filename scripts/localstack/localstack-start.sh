#!/bin/bash

# ${var.project_name} - LocalStack Quick Start with Pro Credentials Setup
# This script combines credential setup and LocalStack deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
show_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        ${var.project_name} - LocalStack Quick Start              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

setup_pro_credentials() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      LocalStack Pro - Credential Setup Wizard         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check if credentials already exist
    if [ -n "$LOCALSTACK_API_KEY" ] || [ -n "$LOCALSTACK_AUTH_TOKEN" ]; then
        echo -e "${YELLOW}Existing credentials detected:${NC}"
        [ -n "$LOCALSTACK_API_KEY" ] && echo -e "  ${GREEN}✓${NC} LOCALSTACK_API_KEY is set"
        [ -n "$LOCALSTACK_AUTH_TOKEN" ] && echo -e "  ${GREEN}✓${NC} LOCALSTACK_AUTH_TOKEN is set"
        echo ""
        read -p "Use existing credentials? (y/n): " use_existing
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            return 0
        fi
        echo ""
        echo -e "${YELLOW}Clearing existing credentials...${NC}"
        unset LOCALSTACK_API_KEY LOCALSTACK_AUTH_TOKEN
    fi
    
    echo "Choose your LocalStack setup:"
    echo "  1) LocalStack Pro with API Key (recommended)"
    echo "  2) LocalStack Pro with Auth Token"
    echo "  3) LocalStack Community Edition (free, no Pro features)"
    echo "  4) Skip credential setup (use existing settings)"
    echo ""
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            echo ""
            echo -e "${YELLOW}Get your API Key from:${NC} https://app.localstack.cloud"
            echo ""
            read -p "Enter your LocalStack API Key: " api_key
            
            if [ -z "$api_key" ]; then
                echo -e "${RED}✗ API Key cannot be empty${NC}"
                return 1
            fi
            
            export LOCALSTACK_API_KEY="$api_key"
            unset LOCALSTACK_AUTH_TOKEN
            export ACTIVATE_PRO=1
            
            # Save to shell profile for persistence
            if ! grep -q "LOCALSTACK_API_KEY" ~/.zshrc 2>/dev/null; then
                echo "" >> ~/.zshrc
                echo "# LocalStack Pro API Key" >> ~/.zshrc
                echo "export LOCALSTACK_API_KEY='$api_key'" >> ~/.zshrc
                echo -e "${GREEN}✓${NC} Saved to ~/.zshrc"
            fi
            
            echo -e "${GREEN}✓ Set up with API Key${NC}"
            ;;
        2)
            echo ""
            echo -e "${YELLOW}Get your Auth Token from:${NC} https://app.localstack.cloud"
            echo ""
            read -p "Enter your LocalStack Auth Token: " auth_token
            
            if [ -z "$auth_token" ]; then
                echo -e "${RED}✗ Auth Token cannot be empty${NC}"
                return 1
            fi
            
            export LOCALSTACK_AUTH_TOKEN="$auth_token"
            unset LOCALSTACK_API_KEY
            export ACTIVATE_PRO=1
            
            # Save to shell profile for persistence
            if ! grep -q "LOCALSTACK_AUTH_TOKEN" ~/.zshrc 2>/dev/null; then
                echo "" >> ~/.zshrc
                echo "# LocalStack Pro Auth Token" >> ~/.zshrc
                echo "export LOCALSTACK_AUTH_TOKEN='$auth_token'" >> ~/.zshrc
                echo -e "${GREEN}✓${NC} Saved to ~/.zshrc"
            fi
            
            echo -e "${GREEN}✓ Set up with Auth Token${NC}"
            ;;
        3)
            export ACTIVATE_PRO=0
            unset LOCALSTACK_API_KEY LOCALSTACK_AUTH_TOKEN
            echo -e "${GREEN}✓ Community Edition enabled${NC}"
            echo -e "${YELLOW}ℹ Pro features (Web UI, Multi-account) will be unavailable${NC}"
            ;;
        4)
            echo -e "${YELLOW}Skipping credential setup${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}✗ Invalid choice${NC}"
            return 1
            ;;
    esac
    
    echo ""
    return 0
}

check_prerequisites() {
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
}

validate_credentials() {
    echo -e "${YELLOW}Validating LocalStack Pro setup...${NC}"
    
    # Check for conflicting credentials
    if [ -n "$LOCALSTACK_API_KEY" ] && [ -n "$LOCALSTACK_AUTH_TOKEN" ]; then
        echo -e "${RED}✗ ERROR: Both LOCALSTACK_API_KEY and LOCALSTACK_AUTH_TOKEN are set${NC}"
        echo -e "${YELLOW}Please use only ONE credential type. Run this script again to fix.${NC}"
        exit 1
    fi
    
    # Set Pro activation based on credentials
    if [ -n "$LOCALSTACK_API_KEY" ] || [ -n "$LOCALSTACK_AUTH_TOKEN" ]; then
        export ACTIVATE_PRO=1
        echo -e "${GREEN}✓ LocalStack Pro credentials found${NC}"
    else
        export ACTIVATE_PRO=0
        echo -e "${YELLOW}ℹ Using LocalStack Community Edition${NC}"
    fi
    
    echo ""
}

# Main execution
show_header
check_prerequisites

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Check for --setup-only flag
if [ "$1" = "--setup-only" ]; then
    setup_pro_credentials
    exit $?
fi

# Setup credentials if needed or requested with --setup flag
if [ "$1" = "--setup" ] || [ -z "$LOCALSTACK_API_KEY" ] && [ -z "$LOCALSTACK_AUTH_TOKEN" ]; then
    if [ "$1" != "--setup" ]; then
        read -p "No Pro credentials found. Set up now? (y/n): " setup_choice
        if [[ "$setup_choice" =~ ^[Yy]$ ]]; then
            setup_pro_credentials || exit 1
        fi
    else
        setup_pro_credentials || exit 1
    fi
fi

validate_credentials

# Start LocalStack
echo -e "${YELLOW}Starting LocalStack...${NC}"
cd "$SCRIPT_DIR"
docker-compose -f docker-compose.localstack.yml up -d
cd "$PROJECT_ROOT"

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
cd "$PROJECT_ROOT/terraform"

export USE_LOCALSTACK=true
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export TF_VAR_github_token="test_token_for_localstack"

# Initialize Terraform with local backend (no S3 for LocalStack)
echo -e "${YELLOW}Initializing Terraform with local backend...${NC}"

# Remove old .terraform directory if it exists (to avoid S3 backend issues)
if [ -d ".terraform" ]; then
    echo -e "${YELLOW}Removing old Terraform initialization...${NC}"
    rm -rf .terraform .terraform.lock.hcl
fi

# Initialize without backend
terraform init -backend=false

# Apply Terraform configuration
echo -e "${YELLOW}Applying Terraform configuration...${NC}"
terraform apply \
  -var-file=environments/local/terraform.tfvars \
  -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}" \
  -auto-approve

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Get dashboard API URL from Terraform outputs
echo -e "${YELLOW}Fetching dashboard API URL...${NC}"
export DASHBOARD_API_URL=$(terraform output -raw dashboard_api_url)
echo -e "${GREEN}✓ API URL: ${DASHBOARD_API_URL}${NC}"
echo ""

# Deploy dashboard
echo -e "${YELLOW}Deploying dashboard...${NC}"
cd "$PROJECT_ROOT/dashboard"
./deploy-localstack.sh
cd "$PROJECT_ROOT"
echo ""

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Complete! 🚀                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Access Points:${NC}"
echo -e "  Dashboard:   ${GREEN}http://localhost:4566/${var.project_name}-dashboard-local/index.html${NC}"
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
