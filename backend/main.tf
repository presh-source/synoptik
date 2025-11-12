# Synoptik - Main Terraform Configuration
# Synoptik Infrastructure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for AWS
  # For LocalStack: use `terraform init -backend=false`
  # For AWS: use `terraform init -backend-config=environments/{env}/backend.tfvars`
  backend "s3" {
    bucket = "synoptik-terraform-state"
    key    = "terraform.tfstate"
    region = var.region
    encrypt = true
    dynamodb_table = "synoptik-terraform-state-lock"
  }
}

# Provider configuration is in localstack-provider.tf

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  merged_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

# ============================================================================
# Core Modules
# ============================================================================

# IAM Roles
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.merged_tags
}

# Secrets Manager for GitHub token and Sentry DSNs
module "secrets" {
  source              = "./modules/secrets"
  project_name        = var.project_name
  environment         = var.environment
  github_token        = var.github_token
  sentry_dsn_frontend = var.sentry_dsn_frontend
  sentry_dsn_backend  = var.sentry_dsn_backend
  tags                = local.merged_tags
}

# Data Lake (S3)
module "data_lake" {
  source         = "./modules/data-lake"
  project_name   = var.project_name
  environment    = var.environment
  use_localstack = local.use_localstack
  tags           = local.merged_tags
}

# ============================================================================
# Pipeline Modules (Uncomment as implemented)
# ============================================================================

# Cold Path Pipeline
module "cold_path" {
  source                   = "./modules/cold-path"
  project_name             = var.project_name
  environment              = var.environment
  github_token_arn         = module.secrets.github_token_arn
  data_lake_bucket_name    = module.data_lake.bucket_name
  tags                     = local.merged_tags
  lambda_timeout           = 300
  lambda_memory            = 512
  requests_per_execution = 10
  sleep_interval           = 1

  depends_on = [module.secrets, module.data_lake]
}

# Hot Path Pipeline
module "hot_path" {
  source      = "./modules/hot-path"
  project_name = var.project_name
  environment = var.environment
  tags        = local.merged_tags

  depends_on = [module.secrets]
}

# Scrubber Path Pipeline
# module "scrubber_path" {
#   source = "./modules/scrubber-path"
#   project_name          = var.project_name
#   environment           = var.environment
#   github_token_arn      = module.secrets.github_token_arn
#   data_lake_bucket_name = module.data_lake.bucket_name
#
#   depends_on = [module.secrets]
# }

# ============================================================================
# Infrastructure Modules (Uncomment as implemented)
# ============================================================================

# Networking (VPC, Subnets, Security Groups)
# module "networking" {
#   source = "./modules/networking"
#   project_name          = var.project_name
#   environment = var.environment
#   vpc_cidr    = var.vpc_cidr
# }

# Data Stores (OpenSearch, Neptune, Athena)
# module "data_stores" {
#   source = "./modules/data-stores"
#   project_name          = var.project_name
#   environment           = var.environment
#   data_lake_bucket_name = module.data_lake.bucket_name
#   vpc_id                = module.networking.vpc_id
#   private_subnet_ids    = module.networking.private_subnet_ids
#
#   depends_on = [module.networking]
# }

# ============================================================================
# Dashboard Module
# ============================================================================

# Dashboard (API Gateway, Lambda, Frontend)
module "dashboard" {
  source                   = "./modules/dashboard"
  project_name             = var.project_name
  environment              = var.environment
  use_localstack           = local.use_localstack
  opensearch_endpoint      = "http://localhost:4566" # Mock
  neptune_endpoint         = "localhost:8182"      # Mock
  cold_path_dynamodb_table = module.cold_path.dynamodb_table_name
  kinesis_stream_name      = module.hot_path.kinesis_stream_name
  scrubber_queue_url       = "http://localhost:4566/000000000000/scrubber-queue" # Mock
  sentry_dsn_secret_arn    = module.secrets.sentry_dsn_backend_arn
  app_version              = var.app_version
  tags                     = local.merged_tags

  depends_on = [module.secrets, module.cold_path]
}

# ============================================================================
# Monitoring Module (Uncomment as implemented)
# ============================================================================

# Monitoring and Alerting
# module "monitoring" {
#   source = "./modules/monitoring"
#   project_name          = var.project_name
#   environment            = var.environment
#   cold_path_lambda_name  = module.cold_path.crawler_lambda_name
#   hot_path_lambda_names  = module.hot_path.lambda_names
#   scrubber_lambda_name   = module.scrubber_path.pinger_lambda_name
#   kinesis_stream_name    = module.hot_path.kinesis_stream_name
#   opensearch_domain_name = module.data_stores.opensearch_domain_name
#   neptune_cluster_id     = module.data_stores.neptune_cluster_id
#
#   depends_on = [module.cold_path, module.hot_path, module.scrubber_path, module.data_stores]
# }
