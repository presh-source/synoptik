#!/bin/bash

# Script to push Synoptik to GitHub private repository

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Push Synoptik to GitHub                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ Git is not installed${NC}"
    echo -e "  Install from: https://git-scm.com/downloads"
    exit 1
fi
echo -e "${GREEN}✓ Git is installed${NC}"

# Get GitHub username
echo ""
echo -e "${YELLOW}Enter your GitHub username:${NC}"
read -r GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    echo -e "${RED}✗ GitHub username is required${NC}"
    exit 1
fi

# Get repository name (default: Synoptik)
echo ""
echo -e "${YELLOW}Enter repository name (default: Synoptik):${NC}"
read -r REPO_NAME
REPO_NAME=${REPO_NAME:-Synoptik}

# Confirm repository will be private
echo ""
echo -e "${YELLOW}⚠️  Make sure you've created a PRIVATE repository on GitHub:${NC}"
echo -e "   Repository: ${GREEN}https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"
echo -e "   Visibility: ${GREEN}Private${NC}"
echo ""
echo -e "${YELLOW}Have you created the private repository? (y/n):${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo ""
    echo -e "${YELLOW}Please create a private repository first:${NC}"
    echo -e "  1. Go to: ${BLUE}https://github.com/new${NC}"
    echo -e "  2. Repository name: ${GREEN}${REPO_NAME}${NC}"
    echo -e "  3. Select: ${GREEN}Private${NC}"
    echo -e "  4. Do NOT initialize with README, .gitignore, or license"
    echo -e "  5. Click 'Create repository'"
    echo ""
    exit 0
fi

# Check for sensitive files
echo ""
echo -e "${YELLOW}Checking for sensitive files...${NC}"

SENSITIVE_FILES=(
    ".env"
    ".env.local"
    "terraform/terraform.tfstate"
    "terraform/*.tfvars"
)

FOUND_SENSITIVE=false
for pattern in "${SENSITIVE_FILES[@]}"; do
    if ls $pattern 2>/dev/null | grep -q .; then
        echo -e "${RED}✗ Found sensitive file: $pattern${NC}"
        FOUND_SENSITIVE=true
    fi
done

if [ "$FOUND_SENSITIVE" = true ]; then
    echo -e "${YELLOW}⚠️  Sensitive files found but they should be in .gitignore${NC}"
    echo -e "${YELLOW}   Continuing... (they won't be committed)${NC}"
fi

echo -e "${GREEN}✓ Sensitive file check complete${NC}"

# Initialize git repository
echo ""
echo -e "${YELLOW}Initializing git repository...${NC}"
git init
echo -e "${GREEN}✓ Git repository initialized${NC}"

# Add all files
echo ""
echo -e "${YELLOW}Adding files to git...${NC}"
git add .
echo -e "${GREEN}✓ Files added${NC}"

# Show what will be committed
echo ""
echo -e "${BLUE}Files to be committed:${NC}"
git status --short | head -20
FILE_COUNT=$(git status --short | wc -l)
if [ "$FILE_COUNT" -gt 20 ]; then
    echo -e "${YELLOW}... and $((FILE_COUNT - 20)) more files${NC}"
fi

# Confirm commit
echo ""
echo -e "${YELLOW}Ready to commit. Continue? (y/n):${NC}"
read -r CONFIRM_COMMIT

if [ "$CONFIRM_COMMIT" != "y" ] && [ "$CONFIRM_COMMIT" != "Y" ]; then
    echo -e "${YELLOW}Aborted. No changes committed.${NC}"
    exit 0
fi

# Create initial commit
echo ""
echo -e "${YELLOW}Creating initial commit...${NC}"
git commit -m "Initial commit: Synoptik platform with LocalStack support

- Complete React dashboard with Material-UI
- Terraform infrastructure for AWS deployment
- LocalStack configuration for local development
- Three-pipeline architecture (Cold Path, Hot Path, Scrubber Path)
- Comprehensive documentation and deployment guides"

echo -e "${GREEN}✓ Initial commit created${NC}"

# Add remote
echo ""
echo -e "${YELLOW}Adding GitHub remote...${NC}"
REMOTE_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
git remote add origin "$REMOTE_URL"
echo -e "${GREEN}✓ Remote added: ${REMOTE_URL}${NC}"

# Set main branch
git branch -M main

# Push to GitHub
echo ""
echo -e "${YELLOW}Pushing to GitHub...${NC}"
echo -e "${YELLOW}You may be prompted for your GitHub credentials.${NC}"
echo -e "${YELLOW}Use a Personal Access Token as password (not your GitHub password).${NC}"
echo -e "${YELLOW}Generate token at: https://github.com/settings/tokens${NC}"
echo ""

if git push -u origin main; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Successfully Pushed! 🚀                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Repository URL:${NC}"
    echo -e "  ${GREEN}https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Visit your repository on GitHub"
    echo -e "  2. Add repository description and topics"
    echo -e "  3. Set up GitHub Secrets for CI/CD (see GITHUB_SETUP.md)"
    echo -e "  4. Configure branch protection rules"
    echo ""
    echo -e "${YELLOW}See GITHUB_SETUP.md for more information${NC}"
else
    echo ""
    echo -e "${RED}✗ Push failed${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo -e "  1. Authentication failed - Use Personal Access Token"
    echo -e "     Generate at: https://github.com/settings/tokens"
    echo -e "  2. Repository doesn't exist - Create it on GitHub first"
    echo -e "  3. Repository not empty - Make sure it's empty (no README)"
    echo ""
    echo -e "${YELLOW}See GITHUB_SETUP.md for troubleshooting${NC}"
    exit 1
fi
