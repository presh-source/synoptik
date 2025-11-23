# Domain and Certificate Module - Providers

# CloudFront requires certificates to be in us-east-1 region
# This provider configuration allows the module to create certificates in us-east-1
# while other resources can be in any region

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
