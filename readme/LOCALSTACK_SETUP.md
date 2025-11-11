# LocalStack Setup Guide

This guide covers setting up and deploying the Synoptik platform to LocalStack for local development and testing.

## What is LocalStack?

LocalStack is a fully functional local AWS cloud stack that allows you to develop and test cloud applications offline. It provides local implementations of AWS services like S3, DynamoDB, Lambda, API Gateway, and more.

## Prerequisites

### 1. Install Docker

LocalStack runs in Docker containers.

**macOS:**
```bash
brew install docker
# Or download Docker Desktop from https://www.docker.com/products/docker-desktop
```

**Linux:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### 2. Install LocalStack CLI

```bash
# Using pip
pip install localstack

# Or using Homebrew (macOS)
brew install localstack/tap/localstack-cli
```

### 3. Install AWS CLI Local Wrapper

```bash
pip install awscli-local
```

This provides the `awslocal` command, which is a wrapper around `aws` CLI that automatically points to LocalStack.

### 4. Install Node.js and npm

```bash
# macOS
brew install node

# Or download from https://nodejs.org/
```

### 5. Install Terraform

```bash
# macOS
brew install terraform

# Or download from https://www.terraform.io/downloads
```

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Start LocalStack with all required services
docker-compose -f docker-compose.localstack.yml up -d

# Check status
docker-compose -f docker-compose.localstack.yml ps

# View logs
docker-compose -f docker-compose.localstack.yml logs -f localstack
```

### Option 2: Using LocalStack CLI

```bash
# Start LocalStack
localstack start -d

# Check status
localstack status

# View logs
localstack logs
```

## Verify LocalStack is Running

```bash
# Check health endpoint
curl http://localhost:4566/_localstack/health

# Should return JSON with service statuses
```

## Deploy Infrastructure with Terraform

### 1. Configure Terraform for LocalStack

```bash
cd terraform

# Set LocalStack environment variables
export USE_LOCALSTACK=true
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Set GitHub token (can be fake for LocalStack)
export TF_VAR_github_token="fake_token_for_localstack"
```

### 2. Initialize and Apply Terraform

```bash
# Initialize Terraform (use local backend for LocalStack)
terraform init

# Plan deployment
terraform plan \
  -var-file=environments/local/terraform.tfvars \
  -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}"

# Apply configuration
terraform apply \
  -var-file=environments/local/terraform.tfvars \
  -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}" \
  -auto-approve
```

### 3. Verify Resources

```bash
# List S3 buckets
awslocal s3 ls

# List DynamoDB tables
awslocal dynamodb list-tables

# List Lambda functions
awslocal lambda list-functions

# List API Gateways
awslocal apigateway get-rest-apis
```

## Deploy Dashboard Frontend

### 1. Build and Deploy to LocalStack

```bash
cd dashboard

# Run the LocalStack deployment script
./deploy-localstack.sh
```

The script will:
1. Check if LocalStack is running
2. Install dependencies
3. Build the React application
4. Create S3 bucket in LocalStack
5. Upload files to LocalStack S3
6. Configure bucket for website hosting
7. Display access URLs

### 2. Access the Dashboard

After deployment, the dashboard will be available at:

- **S3 Website URL**: `http://synoptik-dashboard-local.s3-website.localhost.localstack.cloud:4566`
- **Direct S3 URL**: `http://localhost:4566/synoptik-dashboard-local/index.html`

## Environment Configuration

### Dashboard Environment Variables

Create `.env.local` in the dashboard directory:

```bash
# LocalStack API Gateway endpoint
VITE_API_URL=http://localhost:4566/restapis/local-api-id/local/_user_request_

# Or if running backend locally outside LocalStack
VITE_API_URL=http://localhost:8080
```

### Terraform LocalStack Configuration

The Terraform configuration automatically detects LocalStack when you set:

```bash
export USE_LOCALSTACK=true
```

Or pass it as a variable:

```bash
terraform apply -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}"
```

## Working with LocalStack Services

### S3

```bash
# Create bucket
awslocal s3 mb s3://my-bucket

# List buckets
awslocal s3 ls

# Upload file
awslocal s3 cp file.txt s3://my-bucket/

# Download file
awslocal s3 cp s3://my-bucket/file.txt ./

# Sync directory
awslocal s3 sync ./dist s3://my-bucket/
```

### DynamoDB

```bash
# List tables
awslocal dynamodb list-tables

# Describe table
awslocal dynamodb describe-table --table-name my-table

# Scan table
awslocal dynamodb scan --table-name my-table

# Put item
awslocal dynamodb put-item \
  --table-name my-table \
  --item '{"id":{"S":"123"},"name":{"S":"Test"}}'
```

### Lambda

```bash
# List functions
awslocal lambda list-functions

# Invoke function
awslocal lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json

# View logs
awslocal logs tail /aws/lambda/my-function --follow
```

### API Gateway

```bash
# List APIs
awslocal apigateway get-rest-apis

# Get API details
awslocal apigateway get-rest-api --rest-api-id <api-id>

# Test endpoint
curl http://localhost:4566/restapis/<api-id>/local/_user_request_/endpoint
```

### Secrets Manager

```bash
# Create secret
awslocal secretsmanager create-secret \
  --name github-token \
  --secret-string "my-secret-token"

# Get secret value
awslocal secretsmanager get-secret-value --secret-id github-token
```

## Data Persistence

LocalStack supports data persistence across restarts.

### Enable Persistence

Already configured in `docker-compose.localstack.yml`:

```yaml
environment:
  - PERSISTENCE=1
  - DATA_DIR=/tmp/localstack/data
volumes:
  - "./localstack-data:/tmp/localstack"
```

### Clear Persisted Data

```bash
# Stop LocalStack
docker-compose -f docker-compose.localstack.yml down

# Remove persisted data
rm -rf ./localstack-data

# Start fresh
docker-compose -f docker-compose.localstack.yml up -d
```

## Debugging and Troubleshooting

### View LocalStack Logs

```bash
# Docker Compose
docker-compose -f docker-compose.localstack.yml logs -f

# LocalStack CLI
localstack logs -f
```

### Check Service Health

```bash
curl http://localhost:4566/_localstack/health | jq
```

### Common Issues

**Issue: Port 4566 already in use**
```bash
# Find process using port
lsof -i :4566

# Kill the process
kill -9 <PID>
```

**Issue: Docker socket permission denied**
```bash
# Add user to docker group (Linux)
sudo usermod -aG docker $USER
newgrp docker
```

**Issue: Services not starting**
```bash
# Check Docker is running
docker ps

# Restart LocalStack
docker-compose -f docker-compose.localstack.yml restart
```

**Issue: Lambda functions not executing**
```bash
# Ensure Docker socket is mounted
# Check docker-compose.localstack.yml has:
volumes:
  - "/var/run/docker.sock:/var/run/docker.sock"
```

### Enable Debug Mode

```bash
# In docker-compose.localstack.yml
environment:
  - DEBUG=1
  - LS_LOG=trace
```

## LocalStack Pro Features (Optional)

LocalStack Pro provides additional features:

- Advanced Lambda features (layers, container images)
- CloudFront distributions
- Cognito user pools
- RDS databases
- And more...

### Enable LocalStack Pro

1. Get API key from https://app.localstack.cloud
2. Set environment variable:
   ```bash
   export LOCALSTACK_API_KEY=your-api-key
   ```
3. Update docker-compose.localstack.yml:
   ```yaml
   environment:
     - LOCALSTACK_API_KEY=${LOCALSTACK_API_KEY}
   ```

## Testing the Complete Stack

### 1. Start LocalStack

```bash
docker-compose -f docker-compose.localstack.yml up -d
```

### 2. Deploy Infrastructure

```bash
cd terraform
export USE_LOCALSTACK=true
export TF_VAR_github_token="test"
terraform init
terraform apply -var-file=environments/local/terraform.tfvars -auto-approve
```

### 3. Deploy Dashboard

```bash
cd ../dashboard
./deploy-localstack.sh
```

### 4. Test the Dashboard

Open browser to:
- http://localhost:4566/synoptik-dashboard-local/index.html

### 5. Test API Endpoints

```bash
# Get pipeline status
curl http://localhost:4566/restapis/<api-id>/local/_user_request_/pipeline-status

# Get metrics
curl http://localhost:4566/restapis/<api-id>/local/_user_request_/metrics/realtime
```

## Development Workflow

### Typical Development Cycle

1. **Start LocalStack**
   ```bash
   docker-compose -f docker-compose.localstack.yml up -d
   ```

2. **Deploy/Update Infrastructure**
   ```bash
   cd terraform
   terraform apply -var-file=environments/local/terraform.tfvars -auto-approve
   ```

3. **Deploy/Update Dashboard**
   ```bash
   cd dashboard
   ./deploy-localstack.sh
   ```

4. **Make Changes and Test**
   - Edit code
   - Rebuild and redeploy
   - Test in browser

5. **View Logs**
   ```bash
   localstack logs -f
   ```

6. **Stop LocalStack**
   ```bash
   docker-compose -f docker-compose.localstack.yml down
   ```

## Comparison: LocalStack vs AWS

| Feature | LocalStack | AWS |
|---------|-----------|-----|
| Cost | Free (Community) / Paid (Pro) | Pay per use |
| Speed | Fast (local) | Network latency |
| Internet | Not required | Required |
| Data | Ephemeral/Persistent | Persistent |
| Services | Subset of AWS | All AWS services |
| Testing | Ideal | Production |

## Best Practices

1. **Use LocalStack for Development**: Test locally before deploying to AWS
2. **Keep Terraform DRY**: Use same Terraform code for LocalStack and AWS
3. **Environment Variables**: Use env vars to switch between LocalStack and AWS
4. **Data Seeding**: Create scripts to seed test data in LocalStack
5. **CI/CD Integration**: Run tests against LocalStack in CI pipeline
6. **Version Control**: Don't commit LocalStack data directory
7. **Resource Cleanup**: Regularly clean up LocalStack resources

## Cost Savings

Using LocalStack for development can save significant costs:

- **No AWS charges** during development
- **Faster iteration** without network latency
- **Unlimited testing** without worrying about costs
- **Parallel development** without resource conflicts

## Additional Resources

- **LocalStack Docs**: https://docs.localstack.cloud
- **LocalStack GitHub**: https://github.com/localstack/localstack
- **AWS CLI Local**: https://github.com/localstack/awscli-local
- **Terraform LocalStack**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/custom-service-endpoints

## Support

For LocalStack issues:
1. Check LocalStack logs: `localstack logs`
2. Visit LocalStack Slack: https://localstack.cloud/slack
3. GitHub Issues: https://github.com/localstack/localstack/issues

For project-specific issues:
1. Check this documentation
2. Review Terraform outputs
3. Verify environment variables
4. Test individual services with `awslocal`
