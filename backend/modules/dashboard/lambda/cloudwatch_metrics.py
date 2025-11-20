"""
CloudWatch Metrics Lambda
Fetches CloudWatch metrics for all pipelines
"""

import json
import os
from datetime import datetime, timedelta, timezone
from typing import Any

import boto3

# AWS Lambda Powertools
from aws_lambda_powertools import Logger, Metrics, Tracer
from botocore.exceptions import ClientError

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
ENVIRONMENT = os.environ["ENVIRONMENT"]

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-cloudwatch-metrics")
tracer = Tracer(service=f"{PROJECT_NAME}-cloudwatch-metrics")
metrics = Metrics(
    namespace=f"{PROJECT_NAME.title()}/Dashboard", service="cloudwatch-metrics"
)

# Initialize AWS clients
cloudwatch = boto3.client("cloudwatch")
lambda_client = boto3.client("lambda")

# Lambda function names by pipeline
LAMBDA_FUNCTIONS = {
    "cold_path": f"{ENVIRONMENT}-{PROJECT_NAME}-crawler",
}


def get_metric_statistics(
    namespace: str,
    metric_name: str,
    dimensions: list[dict[str, str]],
    period: int = 3600,
    statistic: str = "Average",
) -> float | None:
    """
    Helper function to get CloudWatch metric statistics
    """
    try:
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=1)

        response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=dimensions,
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=[statistic],
        )

        if response["Datapoints"]:
            datapoints = sorted(
                response["Datapoints"], key=lambda x: x["Timestamp"], reverse=True
            )
            return datapoints[0][statistic]

        return 0.0

    except ClientError as e:
        logger.error(f"Error getting metric {metric_name}: {e}")
        return None


def calculate_error_rate(function_name: str) -> float:
    """
    Calculate error rate for a Lambda function (errors / invocations)
    """
    try:
        dimensions = [{"Name": "FunctionName", "Value": function_name}]

        # Get errors
        errors = (
            get_metric_statistics("AWS/Lambda", "Errors", dimensions, statistic="Sum")
            or 0.0
        )

        # Get invocations
        invocations = (
            get_metric_statistics(
                "AWS/Lambda", "Invocations", dimensions, statistic="Sum"
            )
            or 0.0
        )

        if invocations > 0:
            return (errors / invocations) * 100

        return 0.0

    except Exception as e:
        logger.error(f"Error calculating error rate for {function_name}: {e}")
        return 0.0


def get_lambda_metrics(function_name: str) -> dict[str, Any]:
    """
    Get comprehensive metrics for a Lambda function
    """
    try:
        dimensions = [{"Name": "FunctionName", "Value": function_name}]

        # Get invocations (for rate calculation)
        invocations = (
            get_metric_statistics(
                "AWS/Lambda", "Invocations", dimensions, statistic="Sum"
            )
            or 0.0
        )

        # Get errors
        errors = (
            get_metric_statistics("AWS/Lambda", "Errors", dimensions, statistic="Sum")
            or 0.0
        )

        # Get duration
        duration = (
            get_metric_statistics(
                "AWS/Lambda", "Duration", dimensions, statistic="Average"
            )
            or 0.0
        )

        # Get throttles
        throttles = (
            get_metric_statistics(
                "AWS/Lambda", "Throttles", dimensions, statistic="Sum"
            )
            or 0.0
        )

        # Get concurrent executions
        concurrent = (
            get_metric_statistics(
                "AWS/Lambda", "ConcurrentExecutions", dimensions, statistic="Maximum"
            )
            or 0.0
        )

        # Calculate error rate
        error_rate = (errors / invocations * 100) if invocations > 0 else 0.0

        return {
            "invocations": invocations,
            "errors": errors,
            "error_rate": round(error_rate, 2),
            "duration_ms": round(duration, 2),
            "throttles": throttles,
            "concurrent_executions": concurrent,
        }

    except Exception as e:
        logger.error(f"Error getting Lambda metrics for {function_name}: {e}")
        return {
            "invocations": 0,
            "errors": 0,
            "error_rate": 0.0,
            "duration_ms": 0,
            "throttles": 0,
            "concurrent_executions": 0,
        }


def get_crawler_metrics(crawler_type: str, time_period: int = 3600) -> dict[str, Any]:
    """
    Get metrics for a specific crawler type (repo or user)

    Args:
        crawler_type: Either "repo" or "user"
        time_period: Time period in seconds (default 3600 = 1 hour)

    Returns:
        Dictionary with crawler metrics including rates and counts
    """
    try:
        namespace = f"{PROJECT_NAME.title()}/ColdPath"
        dimensions = [{"Name": "CrawlerType", "Value": crawler_type}]

        # Get total items crawled in the time period
        items_crawled = (
            get_metric_statistics(
                namespace,
                "ItemsCrawled",
                dimensions,
                period=time_period,
                statistic="Sum",
            )
            or 0.0
        )

        # Get request count
        request_count = (
            get_metric_statistics(
                namespace,
                "APIRequests",
                dimensions,
                period=time_period,
                statistic="Sum",
            )
            or 0.0
        )

        # Get run count
        run_count = (
            get_metric_statistics(
                namespace,
                "CrawlerRuns",
                dimensions,
                period=time_period,
                statistic="Sum",
            )
            or 0.0
        )

        # Calculate rates
        hours = time_period / 3600
        minutes = time_period / 60
        seconds = time_period

        rate_per_hour = items_crawled / hours if hours > 0 else 0.0
        rate_per_minute = items_crawled / minutes if minutes > 0 else 0.0
        rate_per_second = items_crawled / seconds if seconds > 0 else 0.0

        return {
            "total_crawled": int(items_crawled),
            "rate_per_hour": round(rate_per_hour, 2),
            "rate_per_minute": round(rate_per_minute, 2),
            "rate_per_second": round(rate_per_second, 4),
            "request_count": int(request_count),
            "run_count": int(run_count),
        }

    except Exception as e:
        logger.error(f"Error getting {crawler_type} crawler metrics: {e}")
        return {
            "total_crawled": 0,
            "rate_per_hour": 0.0,
            "rate_per_minute": 0.0,
            "rate_per_second": 0.0,
            "request_count": 0,
            "run_count": 0,
        }


def get_cold_path_metrics() -> dict[str, Any]:
    """
    Get CloudWatch metrics for Cold Path pipeline including crawler-specific metrics
    """
    try:
        function_name = LAMBDA_FUNCTIONS["cold_path"]
        lambda_metrics = get_lambda_metrics(function_name)

        # Get custom metric for API request rate
        api_request_rate = (
            get_metric_statistics(
                f"{PROJECT_NAME.title()}/ColdPath",
                "APIRequestRate",
                [],
                statistic="Average",
            )
            or 0.0
        )

        # Get repositories processed rate
        repos_processed = (
            get_metric_statistics(
                f"{PROJECT_NAME.title()}/ColdPath",
                "RepositoriesProcessed",
                [],
                statistic="Sum",
            )
            or 0.0
        )

        # Get crawler-specific metrics
        repo_crawler_metrics = get_crawler_metrics("repo")
        user_crawler_metrics = get_crawler_metrics("user")

        return {
            "error_rate": lambda_metrics["error_rate"],
            "api_request_rate": round(api_request_rate, 2),
            "repositories_processed": repos_processed,
            "lambda_duration_ms": lambda_metrics["duration_ms"],
            "lambda_throttles": lambda_metrics["throttles"],
            "lambda_invocations": lambda_metrics["invocations"],
            "lambda_errors": lambda_metrics["errors"],
            "repo_crawler": repo_crawler_metrics,
            "user_crawler": user_crawler_metrics,
        }

    except Exception as e:
        logger.error(f"Error getting Cold Path metrics: {e}")
        return {
            "error_rate": 0.0,
            "api_request_rate": 0.0,
            "repositories_processed": 0,
            "lambda_duration_ms": 0,
            "lambda_throttles": 0,
            "repo_crawler": {
                "total_crawled": 0,
                "rate_per_hour": 0.0,
                "rate_per_minute": 0.0,
                "rate_per_second": 0.0,
                "request_count": 0,
                "run_count": 0,
            },
            "user_crawler": {
                "total_crawled": 0,
                "rate_per_hour": 0.0,
                "rate_per_minute": 0.0,
                "rate_per_second": 0.0,
                "request_count": 0,
                "run_count": 0,
            },
        }


def get_overall_system_metrics() -> dict[str, Any]:
    """
    Get overall system-wide metrics
    """
    try:
        # Get all Lambda functions in the environment
        all_functions = []
        paginator = lambda_client.get_paginator("list_functions")

        for page in paginator.paginate():
            for func in page["Functions"]:
                if func["FunctionName"].startswith(f"{ENVIRONMENT}-{PROJECT_NAME}"):
                    all_functions.append(func["FunctionName"])

        # Calculate aggregate metrics
        total_invocations = 0
        total_errors = 0
        total_throttles = 0

        for func_name in all_functions:
            metrics = get_lambda_metrics(func_name)
            total_invocations += metrics["invocations"]
            total_errors += metrics["errors"]
            total_throttles += metrics["throttles"]

        overall_error_rate = (
            (total_errors / total_invocations * 100) if total_invocations > 0 else 0.0
        )

        return {
            "total_lambda_functions": len(all_functions),
            "total_invocations": total_invocations,
            "total_errors": total_errors,
            "total_throttles": total_throttles,
            "overall_error_rate": round(overall_error_rate, 2),
        }

    except Exception as e:
        logger.error(f"Error getting overall system metrics: {e}")
        return {
            "total_lambda_functions": 0,
            "total_invocations": 0,
            "total_errors": 0,
            "total_throttles": 0,
            "overall_error_rate": 0.0,
        }


@logger.inject_lambda_context(log_event=True)
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(_event, _context):
    """
    API Gateway handler for /api/metrics/cloudwatch endpoint
    Returns CloudWatch metrics for all pipelines
    """
    try:
        # Get metrics for Cold Path pipeline
        cold_path = get_cold_path_metrics()
        overall = get_overall_system_metrics()

        response = {
            "cold_path": cold_path,
            "overall": overall,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "period": "last_1_hour",
        }

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "GET,OPTIONS",
            },
            "body": json.dumps(response),
        }

    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "GET,OPTIONS",
            },
            "body": json.dumps({"error": "Internal server error", "message": str(e)}),
        }
