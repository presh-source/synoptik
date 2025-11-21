"""
AppSync resolver Lambda for pipeline status queries
Reuses existing business logic from pipeline_status.py
"""

import json
import logging
import os
from datetime import datetime, timedelta, timezone

import boto3

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

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
    logger.info(
        f"Fetching CloudWatch metrics for {crawler_type} crawler, "
        f"time_period_hours={time_period_hours}"
    )

    try:
        namespace = f"{PROJECT_NAME.title()}/ColdPath"

        # Map crawler type to service name used in Powertools Metrics
        service_name = "crawler" if crawler_type == "repo" else "user-crawler"

        dimensions = [
            {"Name": "CrawlerType", "Value": crawler_type},
            {"Name": "service", "Value": service_name},
        ]
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=time_period_hours)
        period = time_period_hours * 3600

        # Get items crawled
        try:
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
            logger.info(f"Retrieved ItemsCrawled: {items_crawled}")
        except Exception as e:
            logger.error(f"Failed to get ItemsCrawled metric: {e}")
            items_crawled = 0

        # Get request count
        try:
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
            logger.info(f"Retrieved APIRequests: {request_count}")
        except Exception as e:
            logger.error(f"Failed to get APIRequests metric: {e}")
            request_count = 0

        # Get run count
        try:
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
                runs_response["Datapoints"][0]["Sum"]
                if runs_response["Datapoints"]
                else 0
            )
            logger.info(f"Retrieved CrawlerRuns: {run_count}")
        except Exception as e:
            logger.error(f"Failed to get CrawlerRuns metric: {e}")
            run_count = 0

        # Calculate rates
        hours = time_period_hours
        minutes = hours * 60
        seconds = minutes * 60

        metrics = {
            "totalCrawled": int(items_crawled),
            "ratePerHour": (
                float(round(items_crawled / hours, 2)) if hours > 0 else 0.0
            ),
            "ratePerMinute": (
                float(round(items_crawled / minutes, 2)) if minutes > 0 else 0.0
            ),
            "ratePerSecond": (
                float(round(items_crawled / seconds, 4)) if seconds > 0 else 0.0
            ),
            "requestCount": int(request_count),
            "runCount": int(run_count),
        }

        logger.info(f"Successfully calculated metrics for {crawler_type}: {metrics}")
        return metrics

    except Exception as e:
        logger.error(f"Unexpected error getting crawler metrics: {e}", exc_info=True)
        return {
            "totalCrawled": 0,
            "ratePerHour": 0.0,
            "ratePerMinute": 0.0,
            "ratePerSecond": 0.0,
            "requestCount": 0,
            "runCount": 0,
        }


def get_bookmark(key_name: str) -> dict:
    """
    Helper to fetch a bookmark from DynamoDB.
    """
    default_status = {
        "lastProcessedId": 0,
        "totalProcessed": 0,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }

    if not DYNAMODB_TABLE_NAME:
        logger.warning(
            f"DYNAMODB_TABLE_NAME not set, returning defaults for {key_name}"
        )
        return default_status

    try:
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        response = table.get_item(Key={"state_key": key_name})
        item = response.get("Item")

        if not item:
            logger.warning(f"No bookmark found for {key_name}, using defaults")
            return default_status

        status = {
            "lastProcessedId": int(item.get("last_processed_id", 0)),
            "totalProcessed": int(item.get("total_processed", 0)),
            "updatedAt": item.get("updated_at", datetime.now(timezone.utc).isoformat()),
        }

        logger.info(f"Retrieved bookmark for {key_name}: {status}")
        return status

    except Exception as e:
        logger.error(f"Failed to get bookmark for {key_name}: {e}", exc_info=True)
        return default_status


def get_cold_path_status():
    """
    Fetches the status of the cold path historical ingestion including
    crawler metrics.
    """
    logger.info("Starting Cold Path status fetch")

    # Fetch bookmarks
    repo_bookmark = get_bookmark("bookmark")
    user_bookmark = get_bookmark("user_bookmark")

    # Fetch CloudWatch metrics
    repo_metrics = get_crawler_metrics_from_cloudwatch("repo")
    user_metrics = get_crawler_metrics_from_cloudwatch("user")

    # Enrich metrics with bookmark data
    repo_metrics.update(
        {
            "lastProcessedId": repo_bookmark["lastProcessedId"],
            "totalProcessed": repo_bookmark["totalProcessed"],
        }
    )
    user_metrics.update(
        {
            "lastProcessedId": user_bookmark["lastProcessedId"],
            "totalProcessed": user_bookmark["totalProcessed"],
        }
    )

    # Construct response
    # Top-level fields reflect the Repo crawler (primary)
    base_status = repo_bookmark.copy()
    base_status["repoCrawler"] = repo_metrics
    base_status["userCrawler"] = user_metrics

    return base_status


def get_error_rates():
    """
    Fetches error rates for the Cold Path pipeline from CloudWatch.
    """
    logger.info("Starting error rate calculation")

    try:
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=1)
        period = 3600

        # Get error count for Cold Path Lambda functions
        function_name = f"{PROJECT_NAME}-{ENVIRONMENT}-repo-crawler"

        logger.info(f"Querying error rates for function: {function_name}")

        # Get error count
        try:
            errors_response = cloudwatch.get_metric_statistics(
                Namespace="AWS/Lambda",
                MetricName="Errors",
                Dimensions=[
                    {"Name": "FunctionName", "Value": function_name},
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=period,
                Statistics=["Sum"],
            )
            errors = (
                errors_response["Datapoints"][0]["Sum"]
                if errors_response["Datapoints"]
                else 0.0
            )
            logger.info(f"Retrieved Lambda errors: {errors}")
        except Exception as e:
            logger.error(f"Failed to get Lambda errors metric: {e}")
            errors = 0.0

        # Get invocation count
        try:
            invocations_response = cloudwatch.get_metric_statistics(
                Namespace="AWS/Lambda",
                MetricName="Invocations",
                Dimensions=[
                    {"Name": "FunctionName", "Value": function_name},
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=period,
                Statistics=["Sum"],
            )
            invocations = (
                invocations_response["Datapoints"][0]["Sum"]
                if invocations_response["Datapoints"]
                else 0.0
            )
            logger.info(f"Retrieved Lambda invocations: {invocations}")
        except Exception as e:
            logger.error(f"Failed to get Lambda invocations metric: {e}")
            invocations = 0.0

        # Calculate error rate as percentage
        error_rate = (errors / invocations * 100.0) if invocations > 0 else 0.0

        result = {
            "coldPath": round(error_rate, 2),
        }

        logger.info(f"Successfully calculated error rates: {result}")
        return result

    except Exception as e:
        logger.error(f"Unexpected error getting error rates: {e}", exc_info=True)
        # Return zero error rate on failure
        return {
            "coldPath": 0.0,
        }


def get_pipeline_status():
    """
    Get status of Cold Path pipeline, handling partial failures.
    Always returns valid data structure even if individual components fail.
    """
    logger.info("Starting pipeline status aggregation")

    cold_path_status = get_cold_path_status()
    error_rates = get_error_rates()

    logger.info("Successfully aggregated pipeline status")

    return {
        "coldPath": cold_path_status,
        "errorRates": error_rates,
    }


def lambda_handler(event, _context):
    """
    Handle AppSync resolver requests for pipeline status

    Event structure from AppSync:
    {
        "field": "pipelineStatus",
        "arguments": {}
    }
    """
    logger.info(f"AppSync resolver invoked: {json.dumps(event)}")

    try:
        field = event.get("field")

        if field == "pipelineStatus":
            # Reuse existing function
            result = get_pipeline_status()
            logger.info("Pipeline status retrieved successfully")
            return result

        error_msg = f"Unknown field: {field}"
        logger.error(error_msg)
        return {"error": error_msg}

    except Exception as e:
        logger.error(f"Lambda handler error: {e}", exc_info=True)
        raise
