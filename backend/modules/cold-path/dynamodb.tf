# DynamoDB Resources

# DynamoDB table for crawler state management
resource "aws_dynamodb_table" "crawl_state" {
  name         = "${var.environment}-${var.project_name}-crawler-state"
  billing_mode = "PAY_PER_REQUEST" # On-demand capacity
  hash_key     = "state_key"

  attribute {
    name = "state_key"
    type = "S"
  }

  attribute {
    name = "last_processed_id"
    type = "N"
  }

  attribute {
    name = "total_processed"
    type = "N"
  }

  attribute {
    name = "updated_at"
    type = "S"
  }

  attribute {
    name = "organisation"
    type = "S"
  }

  attribute {
    name = "entity"
    type = "S"
  }

  attribute {
    name = "s3_prefix"
    type = "S"
  }

  attribute {
    name = "endpoint"
    type = "S"
  }

  attribute {
    name = "requests_per_execution"
    type = "N"
  }

  attribute {
    name = "sleep_interval"
    type = "N"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = true

  tags = var.tags
}

# Initialize the bookmark with last_processed_id = 0
resource "aws_dynamodb_table_item" "initial_github_repository_bookmark" {
  table_name = aws_dynamodb_table.crawl_state.name
  hash_key   = aws_dynamodb_table.crawl_state.hash_key

  item = jsonencode({
    state_key = {
      S = "U1RBVEUjZ2l0aHViI3JlcG9zaXRvcnk=" # STATE#github#repository
    }
    last_processed_id = {
      N = "0"
    }
    total_processed = {
      N = "0"
    }
    updated_at = {
      S = timestamp()
    }
    organisation = {
      S = "github"
    }
    entity = {
      S = "repository"
    }
    s3_prefix = {
      S = "cold-path/github/repositories"
    }
    endpoint = {
      S = "https://api.github.com/repositories"
    }
    requests_per_execution = {
      N = "1200"
    }
    sleep_interval = {
      N = "0.1"
    }
  })

  lifecycle {
    ignore_changes = [item] # Don't overwrite on subsequent applies
  }
}

# Initialize the user bookmark with last_processed_id = 0
resource "aws_dynamodb_table_item" "initial_github_user_bookmark" {
  table_name = aws_dynamodb_table.crawl_state.name
  hash_key   = aws_dynamodb_table.crawl_state.hash_key

  item = jsonencode({
    state_key = {
      S = "U1RBVEUjZ2l0aHViI3VzZXI=" # STATE#github#user
    }
    last_processed_id = {
      N = "0"
    }
    total_processed = {
      N = "0"
    }
    updated_at = {
      S = timestamp()
    }
    organisation = {
      S = "github"
    }
    entity = {
      S = "user"
    }
    s3_prefix = {
      S = "cold-path/github/users"
    }
    endpoint = {
      S = "https://api.github.com/users"
    }
    requests_per_execution = {
      N = "1200"
    }
    sleep_interval = {
      N = "0.1"
    }
  })

  lifecycle {
    ignore_changes = [item] # Don't overwrite on subsequent applies
  }
}

# DynamoDB Table for Telemetry
resource "aws_dynamodb_table" "telemetry" {
  name         = "${var.environment}-${var.project_name}-crawler-telemetry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "entity"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  attribute {
    name = "run_id"
    type = "S"
  }

  # GSI1: Query by entity type and time
  global_secondary_index {
    name            = "EntityIndex"
    hash_key        = "entity"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # GSI2: Query by run_id
  global_secondary_index {
    name            = "RunIdIndex"
    hash_key        = "run_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = true

  tags = var.tags
}
