# Monitoring Resources

# --------------------------------------------------------------------------------------------------
# SQS Dead Letter Queue
# --------------------------------------------------------------------------------------------------

resource "aws_sqs_queue" "telemetry_processor_dlq" {
  name                      = "${var.environment}-${var.project_name}-telemetry_processor-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = var.tags
}

resource "aws_sqs_queue" "telemetry_aggregator_dlq" {
  name                      = "${var.environment}-${var.project_name}-telemetry-aggregator-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = var.tags
}
