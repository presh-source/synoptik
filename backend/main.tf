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


}

# Provider configuration is in localstack-provider.tf

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Core Modules
# ============================================================================

# IAM Roles
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

# Secrets Manager for GitHub token and Sentry DSNs
module "secrets" {
  source               = "./modules/secrets"
  project_name         = var.project_name
  environment          = var.environment
  github_token         = var.github_token
  sentry_dsn_frontend  = var.sentry_dsn_frontend
  sentry_dsn_backend   = var.sentry_dsn_backend
}

# Data Lake (S3)
module "data_lake" {
  source         = "./modules/data-lake"
  project_name   = var.project_name
  environment    = var.environment
  use_localstack = local.use_localstack
}

# ============================================================================
# Pipeline Modules (Uncomment as implemented)
# ============================================================================

# Cold Path Pipeline
module "cold_path" {
  source                = "./modules/cold-path"
  project_name          = var.project_name
  environment           = var.environment
  github_token_arn      = module.secrets.github_token_arn
  data_lake_bucket_name = module.data_lake.bucket_name

  depends_on = [module.secrets, module.data_lake]
}

# Hot Path Pipeline
# module "hot_path" {
#   source = "./modules/hot-path"
#
#   environment           = var.environment
#   github_token_arn      = module.secrets.github_token_arn
#   data_lake_bucket_name = module.data_lake.bucket_name
#
#   depends_on = [module.secrets]
# }

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
  source         = "./modules/dashboard"
  project_name   = var.project_name
  environment    = var.environment
  use_localstack = local.use_localstack

  # Mock values for unimplemented dependencies
  opensearch_endpoint      = "http://localhost:4566"
  neptune_endpoint         = "localhost:8182"
  cold_path_dynamodb_table = "${var.project_name}-cold-path-state-${var.environment}"
  kinesis_stream_name      = "${var.project_name}-hot-path-stream-${var.environment}"
  scrubber_queue_url       = "http://localhost:4566/000000000000/${var.project_name}-scrubber-queue-${var.environment}"

  # Sentry configuration
  sentry_dsn_secret_arn = module.secrets.sentry_dsn_backend_arn
  app_version           = var.app_version

  depends_on = [module.secrets]
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
