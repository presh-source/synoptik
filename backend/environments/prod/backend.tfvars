# S3 Backend Configuration for Production Environment

bucket         = "synoptik-terraform-state-prod"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "synoptik-terraform-locks-prod"
encrypt        = true
