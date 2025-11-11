# LocalStack Environment Configuration

environment  = "local"
aws_region   = "us-east-1"
project_name = "synoptik"

# Enable LocalStack
localstack_config = {
  enabled  = "true"
  endpoint = "http://localhost:4566"
}

# LocalStack uses fake credentials
# These are ignored but required by Terraform AWS provider
github_token = "fake-token-for-localstack"

# Placeholder Sentry DSNs for local development
sentry_dsn_frontend = "http://localhost:9000/12345"
sentry_dsn_backend  = "http://localhost:9000/67890"
