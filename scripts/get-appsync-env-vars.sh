#!/bin/bash
# Script to retrieve AppSync environment variables after deployment
# Usage: ./scripts/get-appsync-env-vars.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME="synoptik"

echo "=========================================="
echo "AppSync Environment Variables"
echo "Environment: $ENVIRONMENT"
echo "=========================================="
echo ""

# Change to backend directory
cd "$(dirname "$0")/../backend"

# Get Terraform outputs
echo "📡 Retrieving AppSync endpoints..."
GRAPHQL_ENDPOINT=$(terraform output -raw dashboard_appsync_api_url 2>/dev/null || echo "")
REALTIME_ENDPOINT=$(terraform output -raw dashboard_appsync_realtime_url 2>/dev/null || echo "")
API_KEY=$(terraform output -raw appsync_api_key 2>/dev/null || echo "")

if [ -z "$GRAPHQL_ENDPOINT" ]; then
  echo "❌ Error: AppSync module not deployed or outputs not available"
  echo "   Run 'terraform apply' first to deploy the AppSync infrastructure"
  exit 1
fi

echo ""
echo "✅ AppSync Configuration Retrieved"
echo ""
echo "=========================================="
echo "Backend Environment Variables (Crawler Lambdas)"
echo "=========================================="
echo ""
echo "These are automatically configured in Terraform:"
echo ""
echo "dashboard_appsync_api_url=$GRAPHQL_ENDPOINT"
echo ""

echo "=========================================="
echo "Frontend Environment Variables"
echo "=========================================="
echo ""
echo "Add these to frontend/.env.local:"
echo ""
echo "VITE_dashboard_appsync_api_url=$GRAPHQL_ENDPOINT"
echo "VITE_APPSYNC_API_KEY=$API_KEY"
echo "VITE_APPSYNC_REALTIME_URL=$REALTIME_ENDPOINT"
echo ""

echo "=========================================="
echo "Secrets Manager"
echo "=========================================="
echo ""
echo "API key is also stored in AWS Secrets Manager:"
echo "Secret Name: $ENVIRONMENT-$PROJECT_NAME-appsync-api-key"
echo ""
echo "Retrieve with:"
echo "aws secretsmanager get-secret-value \\"
echo "  --secret-id $ENVIRONMENT-$PROJECT_NAME-appsync-api-key \\"
echo "  --query SecretString --output text | jq"
echo ""

# Optionally update .env.local
read -p "Update frontend/.env.local with these values? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  ENV_FILE="../frontend/.env.local"
  
  # Backup existing file
  if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$ENV_FILE.backup"
    echo "📦 Backed up existing .env.local to .env.local.backup"
  fi
  
  # Update or add AppSync variables
  if grep -q "VITE_dashboard_appsync_api_url" "$ENV_FILE" 2>/dev/null; then
    # Update existing values
    sed -i.tmp "s|VITE_dashboard_appsync_api_url=.*|VITE_dashboard_appsync_api_url=$GRAPHQL_ENDPOINT|" "$ENV_FILE"
    sed -i.tmp "s|VITE_APPSYNC_API_KEY=.*|VITE_APPSYNC_API_KEY=$API_KEY|" "$ENV_FILE"
    sed -i.tmp "s|VITE_APPSYNC_REALTIME_URL=.*|VITE_APPSYNC_REALTIME_URL=$REALTIME_ENDPOINT|" "$ENV_FILE"
    rm -f "$ENV_FILE.tmp"
  else
    # Append new values
    echo "" >> "$ENV_FILE"
    echo "# AppSync GraphQL API Configuration" >> "$ENV_FILE"
    echo "VITE_dashboard_appsync_api_url=$GRAPHQL_ENDPOINT" >> "$ENV_FILE"
    echo "VITE_APPSYNC_API_KEY=$API_KEY" >> "$ENV_FILE"
    echo "VITE_APPSYNC_REALTIME_URL=$REALTIME_ENDPOINT" >> "$ENV_FILE"
  fi
  
  echo "✅ Updated $ENV_FILE"
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Verify crawler Lambdas have the dashboard_appsync_api_url:"
echo "   aws lambda get-function-configuration \\"
echo "     --function-name $ENVIRONMENT-$PROJECT_NAME-repo-crawler \\"
echo "     --query 'Environment.Variables.dashboard_appsync_api_url'"
echo ""
echo "2. Test the GraphQL endpoint:"
echo "   curl -X POST \\"
echo "     -H \"x-api-key: $API_KEY\" \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"query\":\"{ __typename }\"}' \\"
echo "     $GRAPHQL_ENDPOINT"
echo ""
echo "3. Start the frontend development server:"
echo "   cd frontend && npm run dev"
echo ""
