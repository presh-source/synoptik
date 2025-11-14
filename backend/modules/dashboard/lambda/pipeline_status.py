"""
Pipeline Status Lambda Function
Returns status of Cold Path, Hot Path, and Scrubber Path pipelines
"""

import json
import os
from datetime import datetime, timedelta, timezone
import boto3
from botocore.exceptions import ClientError
from utils.sentry_config import (
    init_sentry,
    capture_lambda_error,
    add_breadcrumb,
)

# Initialize Sentry
init_sentry()

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME")
KINESIS_STREAM_NAME = os.environ.get("KINESIS_STREAM_NAME")
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
PROJECT_NAME = os.environ.get("PROJECT_NAME")
ENVIRONMENT = os.environ.get("ENVIRONMENT")

# AWS Clients
dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")
sqs = boto3.client("sqs")

# Constants - Approx. total public repos on GitHub as of late 2023
TOTAL_REPOS_TO_CRAWL = 430_000_000


def get_cold_path_status():
    """Fetches the status of the cold path historical ingestion."""
    if not DYNAMODB_TABLE_NAME:
        add_breadcrumb("DYNAMODB_TABLE_NAME not set", level="warning")
        return None

    try:
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        response = table.get_item(Key={"state_key": "bookmark"})
        item = response.get("Item")

        if not item:
            return {
                "lastProcessedId": 0,
                "totalProcessed": 0,
                "ingestionRate": 0,
                "progressPercentage": 0,
                "estimatedCompletion": "N/A",
                "updatedAt": datetime.utcnow().isoformat(),
            }

        total_processed = int(item.get("total_processed", 0))
        progress = (total_processed / TOTAL_REPOS_TO_CRAWL) * 100

        return {
            "lastProcessedId": int(item.get("last_processed_id", 0)),
            "totalProcessed": total_processed,
            "ingestionRate": 0,  # Placeholder - requires historical data to calculate
            "progressPercentage": progress,
            "estimatedCompletion": "Calculating...",  # Placeholder
            "updatedAt": item.get("updated_at", datetime.utcnow().isoformat()),
        }
    except Exception as e:
        add_breadcrumb("Failed to get cold path status", level="error", data={"error": str(e)})
        return None


def get_hot_path_status():
    """Fetches the status of the hot path real-time event processing."""
    if not KINESIS_STREAM_NAME:
        add_breadcrumb("KINESIS_STREAM_NAME not set", level="warning")
        return None
    try:
        # Get iterator age from Kinesis consumer (assumes a metric is set up)
        # This is a placeholder as it requires knowing the consumer Lambda name
        lag_ms = 0
        
        # Get event rate from IncomingRecords metric
        response = cloudwatch.get_metric_statistics(
            Namespace='AWS/Kinesis',
            MetricName='IncomingRecords',
            Dimensions=[{'Name': 'StreamName', 'Value': KINESIS_STREAM_NAME}],
            StartTime=datetime.utcnow() - timedelta(minutes=5),
            EndTime=datetime.utcnow(),
            Period=300,
            Statistics=['Sum']
        )
        
        event_rate_per_5min = response['Datapoints'][0]['Sum'] if response['Datapoints'] else 0
        event_rate_per_min = event_rate_per_5min / 5

        return {
            "eventRate": round(event_rate_per_min),
            "kinesisLag": lag_ms,
            "lastEventTime": datetime.utcnow().isoformat(), # Placeholder
            "processedLast24h": 0, # Placeholder
        }
    except Exception as e:
        add_breadcrumb("Failed to get hot path status", level="error", data={"error": str(e)})
        return None


def get_scrubber_path_status():
    """Fetches the status of the scrubber path for deletion detection."""
    if not SQS_QUEUE_URL:
        add_breadcrumb("SQS_QUEUE_URL not set", level="warning")
        return None
    try:
        response = sqs.get_queue_attributes(
            QueueUrl=SQS_QUEUE_URL,
            AttributeNames=['ApproximateNumberOfMessages']
        )
        queue_depth = int(response['Attributes']['ApproximateNumberOfMessages'])

        return {
            "queueDepth": queue_depth,
            "validationRate": 0,  # Placeholder
            "deletedRepositories": 0,  # Placeholder
            "lastRunTime": datetime.utcnow().isoformat(),  # Placeholder
        }
    except Exception as e:
        add_breadcrumb("Failed to get scrubber path status", level="error", data={"error": str(e)})
        return None


def get_error_rates():
    """Fetches error rates for the pipelines from CloudWatch."""
    # This is a placeholder. A real implementation would query CloudWatch
    # metrics for the 'Errors' metric on each relevant Lambda function.
    try:
        return {
            "coldPath": 0.1,
            "hotPath": 0.05,
            "scrubberPath": 0.01,
        }
    except Exception as e:
        add_breadcrumb("Failed to get error rates", level="error", data={"error": str(e)})
        return None


def get_pipeline_status():
    """
    Get status of all pipelines, handling partial failures.
    """
    add_breadcrumb(message="Fetching all pipeline statuses", category="lambda", level="info")
    
    status = {
        "coldPath": get_cold_path_status(),
        "hotPath": get_hot_path_status(),
        "scrubberPath": get_scrubber_path_status(),
        "errorRates": get_error_rates(),
    }
    
    return status


def lambda_handler(event, context):
    """
    Lambda handler for pipeline status endpoint
    """
    add_breadcrumb(
        message="Pipeline status request received",
        category="lambda",
        level="info",
        data={"event": event},
    )

    try:
        status = get_pipeline_status()

        add_breadcrumb(
            message="Pipeline status retrieved successfully",
            category="lambda",
            level="info",
        )

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "GET,OPTIONS",
            },
            "body": json.dumps(status),
        }

    except Exception as e:
        capture_lambda_error(e, context, extra_context={"endpoint": "pipeline-status"})
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({"error": "Internal Server Error", "message": str(e)}),
        }