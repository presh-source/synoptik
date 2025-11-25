# Cold Path Module - GitHub Repository Crawler Pipeline

# Get current AWS region and account
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
