# S3 Backend Configuration for Production Environment

bucket         = "prod-synoptik-terraform-state"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "prod-synoptik-terraform-locks"
encrypt        = true
