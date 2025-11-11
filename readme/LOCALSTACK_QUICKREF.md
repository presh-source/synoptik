# LocalStack Quick Reference

Quick reference for common LocalStack commands and operations.

## Starting and Stopping

```bash
# Start LocalStack
docker-compose -f docker-compose.localstack.yml up -d

# Stop LocalStack
docker-compose -f docker-compose.localstack.yml down

# Restart LocalStack
docker-compose -f docker-compose.localstack.yml restart

# View logs
docker-compose -f docker-compose.localstack.yml logs -f

# Check status
docker-compose -f docker-compose.localstack.yml ps
```

## Health and Status

```bash
# Check LocalStack health
curl http://localhost:4566/_localstack/health | jq

# Check specific service
curl http://localhost:4566/_localstack/health | jq '.services.s3'

# Get LocalStack version
curl http://localhost:4566/_localstack/info | jq
```

## S3 Commands

```bash
# List buckets
awslocal s3 ls

# Create bucket
awslocal s3 mb s3://my-bucket

# List objects in bucket
awslocal s3 ls s3://my-bucket/

# Upload file
awslocal s3 cp file.txt s3://my-bucket/

# Download file
awslocal s3 cp s3://my-bucket/file.txt ./

# Sync directory
awslocal s3 sync ./dist s3://my-bucket/

# Delete bucket
awslocal s3 rb s3://my-bucket --force
```

## DynamoDB Commands

```bash
# List tables
awslocal dynamodb list-tables

# Describe table
awslocal dynamodb describe-table --table-name my-table

# Scan table
awslocal dynamodb scan --table-name my-table

# Get item
awslocal dynamodb get-item \
  --table-name my-table \
  --key '{"id":{"S":"123"}}'

# Put item
awslocal dynamodb put-item \
  --table-name my-table \
  --item '{"id":{"S":"123"},"name":{"S":"Test"}}'

# Delete table
awslocal dynamodb delete-table --table-name my-table
```

## Lambda Commands

```bash
# List functions
awslocal lambda list-functions

# Get function
awslocal lambda get-function --function-name my-function

# Invoke function
awslocal lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json

# View response
cat response.json

# Update function code
awslocal lambda update-function-code \
  --function-name my-function \
  --zip-file fileb://function.zip

# Delete function
awslocal lambda delete-function --function-name my-function
```

## API Gateway Commands

```bash
# List APIs
awslocal apigateway get-rest-apis

# Get API details
awslocal apigateway get-rest-api --rest-api-id <api-id>

# List resources
awslocal apigateway get-resources --rest-api-id <api-id>

# Test endpoint
curl http://localhost:4566/restapis/<api-id>/local/_user_request_/endpoint
```

## Kinesis Commands

```bash
# List streams
awslocal kinesis list-streams

# Describe stream
awslocal kinesis describe-stream --stream-name my-stream

# Put record
awslocal kinesis put-record \
  --stream-name my-stream \
  --partition-key key1 \
  --data "test data"

# Get shard iterator
awslocal kinesis get-shard-iterator \
  --stream-name my-stream \
  --shard-id shardId-000000000000 \
  --shard-iterator-type LATEST

# Get records
awslocal kinesis get-records --shard-iterator <iterator>
```

## SQS Commands

```bash
# List queues
awslocal sqs list-queues

# Create queue
awslocal sqs create-queue --queue-name my-queue

# Get queue URL
awslocal sqs get-queue-url --queue-name my-queue

# Send message
awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/my-queue \
  --message-body "Hello World"

# Receive messages
awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/my-queue

# Delete queue
awslocal sqs delete-queue \
  --queue-url http://localhost:4566/000000000000/my-queue
```

## Secrets Manager Commands

```bash
# Create secret
awslocal secretsmanager create-secret \
  --name my-secret \
  --secret-string "my-secret-value"

# Get secret value
awslocal secretsmanager get-secret-value --secret-id my-secret

# Update secret
awslocal secretsmanager update-secret \
  --secret-id my-secret \
  --secret-string "new-value"

# Delete secret
awslocal secretsmanager delete-secret --secret-id my-secret
```

## CloudWatch Commands

```bash
# List log groups
awslocal logs describe-log-groups

# Get log streams
awslocal logs describe-log-streams --log-group-name /aws/lambda/my-function

# Get log events
awslocal logs get-log-events \
  --log-group-name /aws/lambda/my-function \
  --log-stream-name 2024/11/11/[LATEST]abc123

# Tail logs
awslocal logs tail /aws/lambda/my-function --follow
```

## IAM Commands

```bash
# List roles
awslocal iam list-roles

# Get role
awslocal iam get-role --role-name my-role

# List policies
awslocal iam list-policies

# Create role
awslocal iam create-role \
  --role-name my-role \
  --assume-role-policy-document file://trust-policy.json
```

## Terraform Commands

```bash
# Initialize with LocalStack
export USE_LOCALSTACK=true
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
terraform init

# Plan with LocalStack
terraform plan \
  -var-file=environments/local/terraform.tfvars \
  -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}"

# Apply with LocalStack
terraform apply \
  -var-file=environments/local/terraform.tfvars \
  -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}" \
  -auto-approve

# Destroy resources
terraform destroy \
  -var-file=environments/local/terraform.tfvars \
  -var="localstack_config={enabled=\"true\",endpoint=\"http://localhost:4566\"}" \
  -auto-approve
```

## Dashboard Commands

```bash
# Deploy to LocalStack
cd dashboard
./deploy-localstack.sh

# Run locally (dev mode)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Debugging

```bash
# Enable debug mode
docker-compose -f docker-compose.localstack.yml down
# Edit docker-compose.localstack.yml and set DEBUG=1
docker-compose -f docker-compose.localstack.yml up -d

# View detailed logs
docker-compose -f docker-compose.localstack.yml logs -f

# Check container status
docker ps | grep localstack

# Execute command in container
docker exec -it synoptik-localstack bash

# Check LocalStack processes
docker exec -it synoptik-localstack ps aux
```

## Data Management

```bash
# Clear all data (stop LocalStack first)
docker-compose -f docker-compose.localstack.yml down
rm -rf ./localstack-data
docker-compose -f docker-compose.localstack.yml up -d

# Backup data
tar -czf localstack-backup.tar.gz ./localstack-data

# Restore data
tar -xzf localstack-backup.tar.gz
```

## Environment Variables

```bash
# Required for LocalStack
export USE_LOCALSTACK=true
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Optional
export LOCALSTACK_ENDPOINT=http://localhost:4566
export TF_VAR_github_token="test_token"
```

## URLs and Endpoints

```bash
# LocalStack Gateway
http://localhost:4566

# Health Check
http://localhost:4566/_localstack/health

# Dashboard (after deployment)
http://localhost:4566/synoptik-dashboard-local/index.html

# S3 Website
http://synoptik-dashboard-local.s3-website.localhost.localstack.cloud:4566

# API Gateway (example)
http://localhost:4566/restapis/<api-id>/local/_user_request_/
```

## Quick Setup

```bash
# One-command setup
./localstack-start.sh

# Manual setup
docker-compose -f docker-compose.localstack.yml up -d
cd terraform && terraform apply -var-file=environments/local/terraform.tfvars -auto-approve
cd ../dashboard && ./deploy-localstack.sh
```

## Useful Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# LocalStack aliases
alias lsup='docker-compose -f docker-compose.localstack.yml up -d'
alias lsdown='docker-compose -f docker-compose.localstack.yml down'
alias lslogs='docker-compose -f docker-compose.localstack.yml logs -f'
alias lshealth='curl http://localhost:4566/_localstack/health | jq'
alias lsreset='docker-compose -f docker-compose.localstack.yml down && rm -rf ./localstack-data && docker-compose -f docker-compose.localstack.yml up -d'

# AWS Local aliases
alias s3ls='awslocal s3 ls'
alias ddbls='awslocal dynamodb list-tables'
alias lambdals='awslocal lambda list-functions'
alias apils='awslocal apigateway get-rest-apis'
```

## Tips and Tricks

1. **Use awslocal instead of aws** - Automatically points to LocalStack
2. **Check health before deploying** - Ensure LocalStack is ready
3. **Enable persistence** - Keep data across restarts
4. **Use Docker logs** - Debug issues quickly
5. **Clear data regularly** - Start fresh when needed
6. **Set environment variables** - Avoid repeating parameters
7. **Use aliases** - Speed up common commands

## Common Patterns

### Deploy and Test Cycle

```bash
# 1. Make changes
vim dashboard/src/pages/PipelineStatusPage.tsx

# 2. Rebuild
cd dashboard && npm run build

# 3. Deploy
./deploy-localstack.sh

# 4. Test
open http://localhost:4566/synoptik-dashboard-local/index.html

# 5. Check logs if issues
docker-compose -f ../docker-compose.localstack.yml logs -f
```

### Infrastructure Update

```bash
# 1. Update Terraform
vim terraform/modules/dashboard/frontend.tf

# 2. Plan changes
cd terraform
terraform plan -var-file=environments/local/terraform.tfvars

# 3. Apply changes
terraform apply -var-file=environments/local/terraform.tfvars -auto-approve

# 4. Verify
awslocal s3 ls
```

### Fresh Start

```bash
# Complete reset
docker-compose -f docker-compose.localstack.yml down
rm -rf ./localstack-data
./localstack-start.sh
```

## Resources

- LocalStack Docs: https://docs.localstack.cloud
- AWS CLI Docs: https://docs.aws.amazon.com/cli/
- Terraform Docs: https://www.terraform.io/docs
