"""
Pipeline Status Lambda Function
Returns status of Cold Path, Hot Path, and Scrubber Path pipelines
"""

import json
import logging
import os
from datetime import datetime, timedelta, timezone

import boto3
from utils.sentry_config import (
    add_breadcrumb,
    capture_lambda_error,
    init_sentry,
)

# Initialize Sentry
init_sentry()

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
        "Starting CloudWatch metrics fetch",
        extra={
            "operation": "get_crawler_metrics_from_cloudwatch",
            "crawler_type": crawler_type,
            "time_period_hours": time_period_hours,
        },
    )

    add_breadcrumb(
        f"Fetching CloudWatch metrics for {crawler_type} crawler",
        category="cloudwatch",
        level="info",
        data={
            "crawler_type": crawler_type,
            "time_period_hours": time_period_hours,
        },
    )

    try:
        namespace = f"{PROJECT_NAME.title()}/ColdPath"
        dimensions = [{"Name": "CrawlerType", "Value": crawler_type}]
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=time_period_hours)
        period = time_period_hours * 3600

        # Log CloudWatch query parameters
        logger.info(
            "CloudWatch query parameters",
            extra={
                "operation": "cloudwatch_query",
                "namespace": namespace,
                "dimensions": dimensions,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "period": period,
                "crawler_type": crawler_type,
            },
        )

        # Get items crawled
        try:
            logger.info(
                "Querying ItemsCrawled metric",
                extra={
                    "operation": "cloudwatch_get_metric",
                    "metric_name": "ItemsCrawled",
                    "crawler_type": crawler_type,
                    "namespace": namespace,
                },
            )

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

            logger.info(
                "Retrieved ItemsCrawled metric",
                extra={
                    "operation": "cloudwatch_metric_result",
                    "metric_name": "ItemsCrawled",
                    "crawler_type": crawler_type,
                    "value": items_crawled,
                    "datapoint_count": len(items_response["Datapoints"]),
                },
            )

            add_breadcrumb(
                f"Retrieved ItemsCrawled metric for {crawler_type}",
                category="cloudwatch",
                level="info",
                data={"items_crawled": items_crawled},
            )
        except Exception as e:
            logger.error(
                "Failed to get ItemsCrawled metric",
                extra={
                    "operation": "cloudwatch_metric_error",
                    "metric_name": "ItemsCrawled",
                    "crawler_type": crawler_type,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )

            add_breadcrumb(
                f"Failed to get ItemsCrawled metric for {crawler_type}",
                category="cloudwatch",
                level="error",
                data={"error": str(e), "error_type": type(e).__name__},
            )
            capture_lambda_error(
                e,
                extra_context={
                    "metric": "ItemsCrawled",
                    "crawler_type": crawler_type,
                    "namespace": namespace,
                },
            )
            items_crawled = 0

        # Get request count
        try:
            logger.info(
                "Querying APIRequests metric",
                extra={
                    "operation": "cloudwatch_get_metric",
                    "metric_name": "APIRequests",
                    "crawler_type": crawler_type,
                    "namespace": namespace,
                },
            )

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

            logger.info(
                "Retrieved APIRequests metric",
                extra={
                    "operation": "cloudwatch_metric_result",
                    "metric_name": "APIRequests",
                    "crawler_type": crawler_type,
                    "value": request_count,
                    "datapoint_count": len(requests_response["Datapoints"]),
                },
            )

            add_breadcrumb(
                f"Retrieved APIRequests metric for {crawler_type}",
                category="cloudwatch",
                level="info",
                data={"request_count": request_count},
            )
        except Exception as e:
            logger.error(
                "Failed to get APIRequests metric",
                extra={
                    "operation": "cloudwatch_metric_error",
                    "metric_name": "APIRequests",
                    "crawler_type": crawler_type,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )

            add_breadcrumb(
                f"Failed to get APIRequests metric for {crawler_type}",
                category="cloudwatch",
                level="error",
                data={"error": str(e), "error_type": type(e).__name__},
            )
            capture_lambda_error(
                e,
                extra_context={
                    "metric": "APIRequests",
                    "crawler_type": crawler_type,
                    "namespace": namespace,
                },
            )
            request_count = 0

        # Get run count
        try:
            logger.info(
                "Querying CrawlerRuns metric",
                extra={
                    "operation": "cloudwatch_get_metric",
                    "metric_name": "CrawlerRuns",
                    "crawler_type": crawler_type,
                    "namespace": namespace,
                },
            )

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

            logger.info(
                "Retrieved CrawlerRuns metric",
                extra={
                    "operation": "cloudwatch_metric_result",
                    "metric_name": "CrawlerRuns",
                    "crawler_type": crawler_type,
                    "value": run_count,
                    "datapoint_count": len(runs_response["Datapoints"]),
                },
            )

            add_breadcrumb(
                f"Retrieved CrawlerRuns metric for {crawler_type}",
                category="cloudwatch",
                level="info",
                data={"run_count": run_count},
            )
        except Exception as e:
            logger.error(
                "Failed to get CrawlerRuns metric",
                extra={
                    "operation": "cloudwatch_metric_error",
                    "metric_name": "CrawlerRuns",
                    "crawler_type": crawler_type,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )

            add_breadcrumb(
                f"Failed to get CrawlerRuns metric for {crawler_type}",
                category="cloudwatch",
                level="error",
                data={"error": str(e), "error_type": type(e).__name__},
            )
            capture_lambda_error(
                e,
                extra_context={
                    "metric": "CrawlerRuns",
                    "crawler_type": crawler_type,
                    "namespace": namespace,
                },
            )
            run_count = 0

        # Calculate rates
        hours = time_period_hours
        minutes = hours * 60
        seconds = minutes * 60

        # Log rate calculation inputs
        logger.info(
            "Calculating crawler rates",
            extra={
                "operation": "rate_calculation",
                "crawler_type": crawler_type,
                "items_crawled": items_crawled,
                "time_period_hours": hours,
                "time_period_minutes": minutes,
                "time_period_seconds": seconds,
            },
        )

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

        # Log calculated metrics
        logger.info(
            "Successfully calculated crawler metrics",
            extra={
                "operation": "rate_calculation_result",
                "crawler_type": crawler_type,
                "metrics": metrics,
            },
        )

        add_breadcrumb(
            f"Successfully calculated metrics for {crawler_type} crawler",
            category="cloudwatch",
            level="info",
            data=metrics,
        )

        return metrics

    except Exception as e:
        logger.error(
            "Unexpected error getting crawler metrics",
            extra={
                "operation": "get_crawler_metrics_error",
                "crawler_type": crawler_type,
                "time_period_hours": time_period_hours,
                "error": str(e),
                "error_type": type(e).__name__,
            },
            exc_info=True,
        )

        add_breadcrumb(
            f"Unexpected error getting {crawler_type} crawler metrics",
            category="cloudwatch",
            level="error",
            data={"error": str(e), "error_type": type(e).__name__},
        )
        capture_lambda_error(
            e,
            extra_context={
                "function": "get_crawler_metrics_from_cloudwatch",
                "crawler_type": crawler_type,
                "time_period_hours": time_period_hours,
            },
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
    """
    Fetches the status of the cold path historical ingestion including
    crawler metrics.
    """
    logger.info(
        "Starting Cold Path status fetch",
        extra={
            "operation": "get_cold_path_status",
            "table_name": DYNAMODB_TABLE_NAME,
        },
    )

    add_breadcrumb(
        "Fetching Cold Path status",
        category="dynamodb",
        level="info",
    )

    # Default values in case of errors
    default_status = {
        "lastProcessedId": 0,
        "totalProcessed": 0,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }

    if not DYNAMODB_TABLE_NAME:
        logger.warning(
            "DYNAMODB_TABLE_NAME environment variable not set",
            extra={
                "operation": "dynamodb_config_error",
                "using_defaults": True,
            },
        )

        add_breadcrumb(
            "DYNAMODB_TABLE_NAME environment variable not set",
            category="dynamodb",
            level="warning",
            data={"using_defaults": True},
        )
        capture_lambda_error(
            ValueError("DYNAMODB_TABLE_NAME not configured"),
            extra_context={
                "function": "get_cold_path_status",
                "issue": "missing_environment_variable",
            },
        )
        base_status = default_status.copy()
    else:
        try:
            logger.info(
                "Querying DynamoDB for bookmark",
                extra={
                    "operation": "dynamodb_get_item",
                    "table_name": DYNAMODB_TABLE_NAME,
                    "key": {"state_key": "bookmark"},
                },
            )

            add_breadcrumb(
                "Querying DynamoDB for bookmark",
                category="dynamodb",
                level="info",
                data={"table_name": DYNAMODB_TABLE_NAME},
            )

            table = dynamodb.Table(DYNAMODB_TABLE_NAME)
            response = table.get_item(Key={"state_key": "bookmark"})
            item = response.get("Item")

            if not item:
                logger.warning(
                    "No bookmark found in DynamoDB",
                    extra={
                        "operation": "dynamodb_query_result",
                        "table_name": DYNAMODB_TABLE_NAME,
                        "item_found": False,
                        "using_defaults": True,
                    },
                )

                add_breadcrumb(
                    "No bookmark found in DynamoDB",
                    category="dynamodb",
                    level="warning",
                    data={"using_defaults": True},
                )
                base_status = default_status.copy()
            else:
                base_status = {
                    "lastProcessedId": int(item.get("last_processed_id", 0)),
                    "totalProcessed": int(item.get("total_processed", 0)),
                    "updatedAt": item.get(
                        "updated_at", datetime.now(timezone.utc).isoformat()
                    ),
                }

                logger.info(
                    "Successfully retrieved bookmark from DynamoDB",
                    extra={
                        "operation": "dynamodb_query_result",
                        "table_name": DYNAMODB_TABLE_NAME,
                        "item_found": True,
                        "last_processed_id": base_status["lastProcessedId"],
                        "total_processed": base_status["totalProcessed"],
                        "updated_at": base_status["updatedAt"],
                    },
                )

                add_breadcrumb(
                    "Successfully retrieved bookmark from DynamoDB",
                    category="dynamodb",
                    level="info",
                    data={
                        "last_processed_id": base_status["lastProcessedId"],
                        "total_processed": base_status["totalProcessed"],
                    },
                )

        except Exception as e:
            logger.error(
                "Failed to get cold path status from DynamoDB",
                extra={
                    "operation": "dynamodb_query_error",
                    "table_name": DYNAMODB_TABLE_NAME,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )

            add_breadcrumb(
                "Failed to get cold path status from DynamoDB",
                category="dynamodb",
                level="error",
                data={
                    "error": str(e),
                    "error_type": type(e).__name__,
                    "table_name": DYNAMODB_TABLE_NAME,
                },
            )
            capture_lambda_error(
                e,
                extra_context={
                    "function": "get_cold_path_status",
                    "table_name": DYNAMODB_TABLE_NAME,
                    "operation": "get_item",
                    "key": {"state_key": "bookmark"},
                },
            )
            base_status = default_status.copy()

    # Add crawler-specific metrics (these functions handle their own errors)
    logger.info(
        "Fetching crawler-specific metrics",
        extra={
            "operation": "fetch_crawler_metrics",
            "crawlers": ["repo", "user"],
        },
    )

    repo_metrics = get_crawler_metrics_from_cloudwatch("repo")
    user_metrics = get_crawler_metrics_from_cloudwatch("user")

    # Enrich crawler metrics with ingestion position (same bookmark for now)
    repo_metrics.update(
        {
            "lastProcessedId": base_status["lastProcessedId"],
            "totalProcessed": base_status["totalProcessed"],
        }
    )
    user_metrics.update(
        {
            "lastProcessedId": base_status["lastProcessedId"],
            "totalProcessed": base_status["totalProcessed"],
        }
    )

    base_status["repoCrawler"] = repo_metrics
    base_status["userCrawler"] = user_metrics

    logger.info(
        "Successfully compiled Cold Path status",
        extra={
            "operation": "cold_path_status_complete",
            "repo_crawler_total": repo_metrics["totalCrawled"],
            "user_crawler_total": user_metrics["totalCrawled"],
            "last_processed_id": base_status["lastProcessedId"],
        },
    )

    add_breadcrumb(
        "Successfully compiled Cold Path status",
        category="lambda",
        level="info",
    )

    return base_status


def get_error_rates():
    """
    Fetches error rates for the Cold Path pipeline from CloudWatch.
    """
    logger.info(
        "Starting error rate calculation",
        extra={
            "operation": "get_error_rates",
        },
    )

    add_breadcrumb(
        "Fetching error rates for Cold Path",
        category="cloudwatch",
        level="info",
    )

    try:
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=1)
        period = 3600

        # Get error count for Cold Path Lambda functions
        function_name = f"{PROJECT_NAME}-{ENVIRONMENT}-repo-crawler"

        logger.info(
            "CloudWatch error rate query parameters",
            extra={
                "operation": "cloudwatch_error_query",
                "function_name": function_name,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "period": period,
                "namespace": "AWS/Lambda",
            },
        )

        add_breadcrumb(
            "Querying CloudWatch for Lambda errors",
            category="cloudwatch",
            level="info",
            data={"function_name": function_name},
        )

        # Get error count
        try:
            logger.info(
                "Querying Lambda Errors metric",
                extra={
                    "operation": "cloudwatch_get_metric",
                    "metric_name": "Errors",
                    "function_name": function_name,
                },
            )

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

            logger.info(
                "Retrieved Lambda errors metric",
                extra={
                    "operation": "cloudwatch_metric_result",
                    "metric_name": "Errors",
                    "function_name": function_name,
                    "value": errors,
                    "datapoint_count": len(errors_response["Datapoints"]),
                },
            )

            add_breadcrumb(
                "Retrieved Lambda errors metric",
                category="cloudwatch",
                level="info",
                data={"errors": errors},
            )
        except Exception as e:
            logger.error(
                "Failed to get Lambda errors metric",
                extra={
                    "operation": "cloudwatch_metric_error",
                    "metric_name": "Errors",
                    "function_name": function_name,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )

            add_breadcrumb(
                "Failed to get Lambda errors metric",
                category="cloudwatch",
                level="error",
                data={"error": str(e), "error_type": type(e).__name__},
            )
            capture_lambda_error(
                e,
                extra_context={
                    "metric": "Errors",
                    "function_name": function_name,
                    "namespace": "AWS/Lambda",
                },
            )
            errors = 0.0

        # Get invocation count
        try:
            logger.info(
                "Querying Lambda Invocations metric",
                extra={
                    "operation": "cloudwatch_get_metric",
                    "metric_name": "Invocations",
                    "function_name": function_name,
                },
            )

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

            logger.info(
                "Retrieved Lambda invocations metric",
                extra={
                    "operation": "cloudwatch_metric_result",
                    "metric_name": "Invocations",
                    "function_name": function_name,
                    "value": invocations,
                    "datapoint_count": len(invocations_response["Datapoints"]),
                },
            )

            add_breadcrumb(
                "Retrieved Lambda invocations metric",
                category="cloudwatch",
                level="info",
                data={"invocations": invocations},
            )
        except Exception as e:
            logger.error(
                "Failed to get Lambda invocations metric",
                extra={
                    "operation": "cloudwatch_metric_error",
                    "metric_name": "Invocations",
                    "function_name": function_name,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )

            add_breadcrumb(
                "Failed to get Lambda invocations metric",
                category="cloudwatch",
                level="error",
                data={"error": str(e), "error_type": type(e).__name__},
            )
            capture_lambda_error(
                e,
                extra_context={
                    "metric": "Invocations",
                    "function_name": function_name,
                    "namespace": "AWS/Lambda",
                },
            )
            invocations = 0.0

        # Calculate error rate as percentage
        logger.info(
            "Calculating error rate",
            extra={
                "operation": "error_rate_calculation",
                "errors": errors,
                "invocations": invocations,
            },
        )

        error_rate = (errors / invocations * 100.0) if invocations > 0 else 0.0

        result = {
            "coldPath": round(error_rate, 2),
        }

        logger.info(
            "Successfully calculated error rates",
            extra={
                "operation": "error_rate_calculation_result",
                "error_rate": result["coldPath"],
                "errors": errors,
                "invocations": invocations,
            },
        )

        add_breadcrumb(
            "Successfully calculated error rates",
            category="cloudwatch",
            level="info",
            data=result,
        )

        return result

    except Exception as e:
        logger.error(
            "Unexpected error getting error rates",
            extra={
                "operation": "get_error_rates_error",
                "error": str(e),
                "error_type": type(e).__name__,
            },
            exc_info=True,
        )

        add_breadcrumb(
            "Unexpected error getting error rates",
            category="cloudwatch",
            level="error",
            data={"error": str(e), "error_type": type(e).__name__},
        )
        capture_lambda_error(
            e,
            extra_context={
                "function": "get_error_rates",
                "operation": "calculate_error_rates",
            },
        )
        # Return zero error rate on failure
        return {
            "coldPath": 0.0,
        }


def get_pipeline_status():
    """
    Get status of Cold Path pipeline, handling partial failures.
    Always returns valid data structure even if individual components fail.
    """
    logger.info(
        "Starting pipeline status aggregation",
        extra={
            "operation": "get_pipeline_status",
        },
    )

    add_breadcrumb(
        message="Fetching Cold Path pipeline status",
        category="lambda",
        level="info",
    )

    cold_path_status = get_cold_path_status()
    error_rates = get_error_rates()

    logger.info(
        "Successfully aggregated pipeline status",
        extra={
            "operation": "get_pipeline_status_complete",
            "cold_path_last_processed": cold_path_status.get("lastProcessedId", 0),
            "error_rate": error_rates.get("coldPath", 0.0),
        },
    )

    return {
        "coldPath": cold_path_status,
        "errorRates": error_rates,
    }


def lambda_handler(event, context):
    """
    Lambda handler for pipeline status endpoint
    """
    logger.info(
        "Lambda invocation started",
        extra={
            "operation": "lambda_handler",
            "request_id": context.aws_request_id if context else "unknown",
            "function_name": context.function_name if context else "unknown",
            "http_method": event.get("httpMethod", "unknown"),
            "path": event.get("path", "unknown"),
        },
    )

    add_breadcrumb(
        message="Pipeline status request received",
        category="lambda",
        level="info",
        data={"event": event},
    )

    try:
        status = get_pipeline_status()

        logger.info(
            "Pipeline status retrieved successfully",
            extra={
                "operation": "lambda_handler_success",
                "request_id": context.aws_request_id if context else "unknown",
                "status_code": 200,
            },
        )

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
                "Access-Control-Allow-Headers": (
                    "Content-Type,X-Amz-Date,Authorization,"
                    "X-Api-Key,X-Amz-Security-Token"
                ),
                "Access-Control-Allow-Methods": "GET,OPTIONS",
            },
            "body": json.dumps(status),
        }

    except Exception as e:
        logger.error(
            "Lambda handler error",
            extra={
                "operation": "lambda_handler_error",
                "request_id": context.aws_request_id if context else "unknown",
                "error": str(e),
                "error_type": type(e).__name__,
                "status_code": 500,
            },
            exc_info=True,
        )

        capture_lambda_error(e, context, extra_context={"endpoint": "pipeline-status"})
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({"error": "Internal Server Error", "message": str(e)}),
        }
