# Data Stores Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets"
  type        = list(string)
}
