"""
AppSync resolver Lambda for crawler metrics queries
Reuses existing business logic for fetching crawler-specific metrics
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
            {"Name": "service", "Value": service_name}
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
        logger.warning(f"DYNAMODB_TABLE_NAME not set, returning defaults for {key_name}")
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


def lambda_handler(event, context):
    """
    Handle AppSync resolver requests for crawler metrics
    
    Event structure from AppSync:
    {
        "field": "repoCrawler" | "userCrawler",
        "crawlerType": "repo" | "user",
        "timePeriodHours": 1
    }
    """
    logger.info(f"AppSync resolver invoked: {json.dumps(event)}")
    
    try:
        crawler_type = event.get('crawlerType')
        time_period = event.get('timePeriodHours', 1)
        
        if not crawler_type:
            error_msg = "Missing required field: crawlerType"
            logger.error(error_msg)
            return {"error": error_msg}
        
        # Get metrics from CloudWatch
        metrics = get_crawler_metrics_from_cloudwatch(crawler_type, time_period)
        
        # Get bookmark data from DynamoDB
        bookmark_key = "bookmark" if crawler_type == "repo" else "user_bookmark"
        bookmark = get_bookmark(bookmark_key)
        
        # Enrich metrics with bookmark data
        metrics['lastProcessedId'] = bookmark['lastProcessedId']
        metrics['totalProcessed'] = bookmark['totalProcessed']
        
        logger.info(f"Successfully retrieved metrics for {crawler_type} crawler")
        return metrics
        
    except Exception as e:
        logger.error(f"Lambda handler error: {e}", exc_info=True)
        raise
