# S3 Backend Configuration for Staging Environment

bucket         = "staging-synoptik-terraform-state"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "staging-synoptik-terraform-locks"
encrypt        = true
