# S3 Backend Configuration for Dev Environment

bucket         = "synoptik-terraform-state-dev"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "synoptik-terraform-locks-dev"
encrypt        = true
