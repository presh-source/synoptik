"""
Pipeline Status Lambda Function
Returns status of Cold Path, Hot Path, and Scrubber Path pipelines
"""

import json
import os
from datetime import datetime, timedelta
import boto3
from utils.sentry_config import (
    init_sentry,
    capture_lambda_error,
    add_breadcrumb,
)

# Initialize Sentry
init_sentry()

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME")
PROJECT_NAME = os.environ.get("PROJECT_NAME")
ENVIRONMENT = os.environ.get("ENVIRONMENT")

# AWS Clients
dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")


def get_crawler_metrics_from_cloudwatch(crawler_type: str, time_period_hours: int = 1):
    """
    Get crawler metrics from CloudWatch for a specific crawler type.

    Args:
        crawler_type: Either "repo" or "user"
        time_period_hours: Number of hours to look back (default 1)

    Returns:
        Dictionary with crawler metrics
    """
    try:
        namespace = f"{PROJECT_NAME.title()}/ColdPath"
        dimensions = [{"Name": "CrawlerType", "Value": crawler_type}]
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=time_period_hours)
        period = time_period_hours * 3600

        # Get items crawled
        items_response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName="ItemsCrawled",
            Dimensions=dimensions,
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=["Sum"],
        )
        items_crawled = (
            items_response["Datapoints"][0]["Sum"]
            if items_response["Datapoints"]
            else 0
        )

        # Get request count
        requests_response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName="APIRequests",
            Dimensions=dimensions,
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=["Sum"],
        )
        request_count = (
            requests_response["Datapoints"][0]["Sum"]
            if requests_response["Datapoints"]
            else 0
        )

        # Get run count
        runs_response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName="CrawlerRuns",
            Dimensions=dimensions,
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=["Sum"],
        )
        run_count = (
            runs_response["Datapoints"][0]["Sum"] if runs_response["Datapoints"] else 0
        )

        # Calculate rates
        hours = time_period_hours
        minutes = hours * 60
        seconds = minutes * 60

        return {
            "totalCrawled": int(items_crawled),
            "ratePerHour": round(items_crawled / hours, 2) if hours > 0 else 0.0,
            "ratePerMinute": round(items_crawled / minutes, 2) if minutes > 0 else 0.0,
            "ratePerSecond": round(items_crawled / seconds, 4) if seconds > 0 else 0.0,
            "requestCount": int(request_count),
            "runCount": int(run_count),
        }

    except Exception as e:
        add_breadcrumb(
            f"Failed to get {crawler_type} crawler metrics",
            level="error",
            data={"error": str(e)},
        )
        return {
            "totalCrawled": 0,
            "ratePerHour": 0.0,
            "ratePerMinute": 0.0,
            "ratePerSecond": 0.0,
            "requestCount": 0,
            "runCount": 0,
        }


def get_cold_path_status():
    """Fetches the status of the cold path historical ingestion including crawler metrics."""
    if not DYNAMODB_TABLE_NAME:
        add_breadcrumb("DYNAMODB_TABLE_NAME not set", level="warning")
        return None

    try:
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        response = table.get_item(Key={"state_key": "bookmark"})
        item = response.get("Item")

        if not item:
            base_status = {
                "lastProcessedId": 0,
                "totalProcessed": 0,
                "updatedAt": datetime.utcnow().isoformat(),
            }
        else:
            base_status = {
                "lastProcessedId": int(item.get("last_processed_id", 0)),
                "totalProcessed": int(item.get("total_processed", 0)),
                "updatedAt": item.get("updated_at", datetime.utcnow().isoformat()),
            }

        # Add crawler-specific metrics
        base_status["repoCrawler"] = get_crawler_metrics_from_cloudwatch("repo")
        base_status["userCrawler"] = get_crawler_metrics_from_cloudwatch("user")

        return base_status

    except Exception as e:
        add_breadcrumb(
            "Failed to get cold path status", level="error", data={"error": str(e)}
        )
        return None


def get_error_rates():
    """Fetches error rates for the Cold Path pipeline from CloudWatch."""
    # This is a placeholder. A real implementation would query CloudWatch
    # metrics for the 'Errors' metric on the Cold Path Lambda function.
    try:
        return {
            "coldPath": 0.1,
        }
    except Exception as e:
        add_breadcrumb(
            "Failed to get error rates", level="error", data={"error": str(e)}
        )
        return None


def get_pipeline_status():
    """
    Get status of Cold Path pipeline, handling partial failures.
    """
    add_breadcrumb(
        message="Fetching Cold Path pipeline status", category="lambda", level="info"
    )

    status = {
        "coldPath": get_cold_path_status(),
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
