# LocalStack Provider Configuration
# This file configures Terraform to use LocalStack instead of AWS

# To use LocalStack, set this environment variable:
# export USE_LOCALSTACK=true

locals {
  use_localstack = tobool(lookup(var.localstack_config, "enabled", "false"))
  localstack_endpoint = lookup(var.localstack_config, "endpoint", "http://localhost:4566")
}

# Override AWS provider endpoints for LocalStack
provider "aws" {
  region = var.aws_region

  # Use LocalStack endpoints if enabled
  skip_credentials_validation = local.use_localstack
  skip_metadata_api_check     = local.use_localstack
  skip_requesting_account_id  = local.use_localstack

  # LocalStack endpoints
  dynamic "endpoints" {
    for_each = local.use_localstack ? [1] : []
    content {
      apigateway     = local.localstack_endpoint
      cloudformation = local.localstack_endpoint
      cloudfront     = local.localstack_endpoint
      cloudwatch     = local.localstack_endpoint
      dynamodb       = local.localstack_endpoint
      ec2            = local.localstack_endpoint
      es             = local.localstack_endpoint
      firehose       = local.localstack_endpoint
      iam            = local.localstack_endpoint
      kinesis        = local.localstack_endpoint
      lambda         = local.localstack_endpoint
      neptune        = local.localstack_endpoint
      s3             = local.localstack_endpoint
      secretsmanager = local.localstack_endpoint
      sns            = local.localstack_endpoint
      sqs            = local.localstack_endpoint
      sts            = local.localstack_endpoint
    }
  }

  # LocalStack uses fake credentials
  dynamic "assume_role" {
    for_each = local.use_localstack ? [] : [1]
    content {
      # Only assume role in real AWS
    }
  }
}
