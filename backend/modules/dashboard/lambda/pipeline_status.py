"""
Pipeline Status Lambda Function
Returns status of Cold Path, Hot Path, and Scrubber Path pipelines
"""

import json
from datetime import datetime
from utils.sentry_config import (
    init_sentry,
    capture_lambda_error,
    add_breadcrumb,
)

# Initialize Sentry
init_sentry()


def lambda_handler(event, context):
    """
    Lambda handler for pipeline status endpoint

    Returns:
        dict: API Gateway response with pipeline status
    """
    add_breadcrumb(
        message="Pipeline status request received",
        category="lambda",
        level="info",
        data={"event": event},
    )

    try:
        # Get pipeline status from various sources
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
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "GET,OPTIONS",
            },
            "body": json.dumps(status),
        }

    except Exception as e:
        # Capture error with context
        capture_lambda_error(
            e, context, extra_context={"endpoint": "pipeline-status", "event": event}
        )

        # Return error response
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps(
                {
                    "error": "Internal server error",
                    "message": str(e),
                    "request_id": context.request_id if context else None,
                }
            ),
        }


def get_pipeline_status():
    """
    Get status of all pipelines

    Returns:
        dict: Pipeline status data
    """
    add_breadcrumb(
        message="Fetching pipeline status", category="database", level="info"
    )

    # Mock data for now - replace with actual data fetching
    # In production, this would query DynamoDB, CloudWatch, etc.

    status = {
        "coldPath": {
            "lastProcessedId": 1000000,
            "totalProcessed": 950000,
            "ingestionRate": 50000,
            "progressPercentage": 95.0,
            "estimatedCompletion": "2 hours",
            "updatedAt": datetime.utcnow().isoformat(),
        },
        "hotPath": {
            "eventRate": 150,
            "kinesisLag": 500,
            "lastEventTime": datetime.utcnow().isoformat(),
            "processedLast24h": 216000,
        },
        "scrubberPath": {
            "queueDepth": 5000,
            "validationRate": 10000,
            "deletedRepositories": 1500,
            "lastRunTime": datetime.utcnow().isoformat(),
        },
        "errorRates": {"coldPath": 0.5, "hotPath": 0.3, "scrubberPath": 0.2},
    }

    return status
