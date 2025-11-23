# Main Terraform Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }

  # For AWS: use `terraform init -backend-config=environments/{env}/backend.tfvars`
  backend "s3" {}
}

# Providers
provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  merged_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

# IAM Roles
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.merged_tags
}

# Data Lake (S3)
module "data_lake" {
  source       = "./modules/data-lake"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.merged_tags
}

# Cold Path Pipeline
module "cold_path" {
  source                 = "./modules/cold-path"
  project_name           = var.project_name
  environment            = var.environment
  github_token           = var.github_token
  data_lake_bucket_name  = module.data_lake.bucket_name
  tags                   = local.merged_tags
  lambda_timeout         = 900
  lambda_memory          = 1024
  requests_per_execution = 700
  sleep_interval         = 1

  appsync_api_url = module.dashboard.appsync_api_url
  appsync_api_id  = module.dashboard.appsync_api_id

  depends_on = [module.data_lake]
}

# Dashboard Module
module "dashboard" {
  source = "./modules/dashboard"
  project_name                       = var.project_name
  environment                        = var.environment
  cold_path_dynamodb_table           = module.cold_path.dynamodb_table_name
  sentry_dsn_backend                 = var.sentry_dsn_backend
  app_version                        = var.app_version
  api_domain_name                    = var.api_domain_name
  appsync_domain_name                = var.appsync_domain_name
  hosted_zone_name                   = var.hosted_zone_name
  acm_certificate_arn                = var.acm_certificate_arn
  api_gateway_cloudwatch_role_arn    = module.iam.api_gateway_cloudwatch_role_arn
  appsync_lambda_invocation_role_arn = module.iam.appsync_lambda_invocation_role_arn
  tags                               = local.merged_tags
}
