# Synoptik - Main Terraform Configuration
# GitHub Digital Twin Infrastructure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend configuration will be provided via backend config file
    # See environments/*/backend.tfvars
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "synoptik"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Roles
module "iam" {
  source = "./modules/iam"

  environment = var.environment
}

# Secrets Manager for GitHub token
module "secrets" {
  source = "./modules/secrets"

  environment  = var.environment
  github_token = var.github_token
}

# Cold Path Pipeline
module "cold_path" {
  source = "./modules/cold-path"

  environment           = var.environment
  github_token_arn      = module.secrets.github_token_arn
  data_lake_bucket_name = module.data_lake.bucket_name

  depends_on = [module.secrets, module.data_lake]
}

# Data Lake (S3)
module "data_lake" {
  source = "./modules/data-lake"

  environment = var.environment
}

# Hot Path Pipeline
module "hot_path" {
  source = "./modules/hot-path"

  environment           = var.environment
  github_token_arn      = module.secrets.github_token_arn
  data_lake_bucket_name = module.data_lake.bucket_name

  depends_on = [module.secrets]
}

# Scrubber Path Pipeline
module "scrubber_path" {
  source = "./modules/scrubber-path"

  environment           = var.environment
  github_token_arn      = module.secrets.github_token_arn
  data_lake_bucket_name = module.data_lake.bucket_name

  depends_on = [module.secrets]
}

# Data Stores (OpenSearch, Neptune, Athena)
module "data_stores" {
  source = "./modules/data-stores"

  environment           = var.environment
  data_lake_bucket_name = module.data_lake.bucket_name
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids

  depends_on = [module.networking]
}

# Networking (VPC, Subnets, Security Groups)
module "networking" {
  source = "./modules/networking"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

# Dashboard (API Gateway, Lambda, Frontend)
module "dashboard" {
  source = "./modules/dashboard"

  environment              = var.environment
  opensearch_endpoint      = module.data_stores.opensearch_endpoint
  neptune_endpoint         = module.data_stores.neptune_endpoint
  cold_path_dynamodb_table = module.cold_path.dynamodb_table_name
  kinesis_stream_name      = module.hot_path.kinesis_stream_name
  scrubber_queue_url       = module.scrubber_path.sqs_queue_url

  depends_on = [module.data_stores, module.cold_path, module.hot_path, module.scrubber_path]
}

# Monitoring and Alerting
module "monitoring" {
  source = "./modules/monitoring"

  environment            = var.environment
  cold_path_lambda_name  = module.cold_path.crawler_lambda_name
  hot_path_lambda_names  = module.hot_path.lambda_names
  scrubber_lambda_name   = module.scrubber_path.pinger_lambda_name
  kinesis_stream_name    = module.hot_path.kinesis_stream_name
  opensearch_domain_name = module.data_stores.opensearch_domain_name
  neptune_cluster_id     = module.data_stores.neptune_cluster_id

  depends_on = [module.cold_path, module.hot_path, module.scrubber_path, module.data_stores]
}
