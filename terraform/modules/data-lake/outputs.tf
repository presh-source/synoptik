# Data Lake Module - Outputs

output "bucket_name" {
  description = "Name of the S3 Data Lake bucket"
  value       = aws_s3_bucket.data_lake.id
}

output "bucket_arn" {
  description = "ARN of the S3 Data Lake bucket"
  value       = aws_s3_bucket.data_lake.arn
}

output "glue_database_name" {
  description = "Name of the Glue Data Catalog database"
  value       = var.use_localstack ? null : aws_glue_catalog_database.glue_db[0].name
}

output "glue_table_repositories_name" {
  description = "Name of the Glue Catalog table for repositories"
  value       = var.use_localstack ? null : aws_glue_catalog_table.repositories[0].name
}
