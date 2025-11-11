# Data Lake Module - S3 Storage

resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.environment}-synoptik-data-lake"

  tags = {
    Name        = "${var.environment}-synoptik-data-lake"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "transition-cold-path-to-glacier"
    status = "Enabled"

    filter {
      prefix = "cold-path/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "expire-hot-path-events"
    status = "Enabled"

    filter {
      prefix = "hot-path/"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Glue Data Catalog Database for Athena queries
resource "aws_glue_catalog_database" "synoptik" {
  name        = "${var.environment}_synoptik"
  description = "Glue Data Catalog for Synoptik data lake"

  catalog_id = data.aws_caller_identity.current.account_id
}

# Glue Catalog Table for Cold Path repositories (Parquet format)
resource "aws_glue_catalog_table" "repositories" {
  name          = "repositories"
  database_name = aws_glue_catalog_database.synoptik.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "parquet"
    "compressionType"           = "snappy"
    "typeOfData"                = "file"
    "EXTERNAL"                  = "TRUE"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2020,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.data_lake.id}/cold-path/year=$${year}/month=$${month}/day=$${day}"
    "parquet.compression"       = "SNAPPY"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.id}/cold-path/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "id"
      type = "bigint"
    }

    columns {
      name = "node_id"
      type = "string"
    }

    columns {
      name = "name"
      type = "string"
    }

    columns {
      name = "full_name"
      type = "string"
    }

    columns {
      name = "private"
      type = "boolean"
    }

    columns {
      name = "owner_id"
      type = "bigint"
    }

    columns {
      name = "owner_login"
      type = "string"
    }

    columns {
      name = "owner_type"
      type = "string"
    }

    columns {
      name = "html_url"
      type = "string"
    }

    columns {
      name = "description"
      type = "string"
    }

    columns {
      name = "fork"
      type = "boolean"
    }

    columns {
      name = "url"
      type = "string"
    }

    columns {
      name = "created_at"
      type = "string"
    }

    columns {
      name = "updated_at"
      type = "string"
    }

    columns {
      name = "pushed_at"
      type = "string"
    }

    columns {
      name = "homepage"
      type = "string"
    }

    columns {
      name = "size"
      type = "int"
    }

    columns {
      name = "stargazers_count"
      type = "int"
    }

    columns {
      name = "watchers_count"
      type = "int"
    }

    columns {
      name = "language"
      type = "string"
    }

    columns {
      name = "forks_count"
      type = "int"
    }

    columns {
      name = "open_issues_count"
      type = "int"
    }

    columns {
      name = "default_branch"
      type = "string"
    }

    columns {
      name = "score"
      type = "double"
    }

    columns {
      name = "has_issues"
      type = "boolean"
    }

    columns {
      name = "has_projects"
      type = "boolean"
    }

    columns {
      name = "has_downloads"
      type = "boolean"
    }

    columns {
      name = "has_wiki"
      type = "boolean"
    }

    columns {
      name = "has_pages"
      type = "boolean"
    }

    columns {
      name = "license_name"
      type = "string"
    }

    columns {
      name = "license_key"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "int"
  }

  partition_keys {
    name = "month"
    type = "int"
  }

  partition_keys {
    name = "day"
    type = "int"
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
