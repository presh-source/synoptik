# S3 Backend Configuration for Staging Environment

bucket         = "synoptik-terraform-state-staging"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "synoptik-terraform-locks-staging"
encrypt        = true
