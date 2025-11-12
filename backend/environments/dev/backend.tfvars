# S3 Backend Configuration for Dev Environment

bucket         = "dev-synoptik-terraform-state"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "dev-synoptik-terraform-locks"
encrypt        = true
