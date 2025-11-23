# Providers
provider "aws" {
  region = var.aws_region
}

# Temporary alias to allow destroying orphaned resources
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
