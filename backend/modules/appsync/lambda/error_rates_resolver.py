"""
AppSync resolver Lambda for error rates queries
Reuses existing business logic for fetching error rate metrics
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
PROJECT_NAME = os.environ.get("PROJECT_NAME")
ENVIRONMENT = os.environ.get("ENVIRONMENT")

# AWS Clients
cloudwatch = boto3.client("cloudwatch")


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


def lambda_handler(event, context):
    """
    Handle AppSync resolver requests for error rates
    
    Event structure from AppSync:
    {
        "field": "errorRates",
        "arguments": {}
    }
    """
    logger.info(f"AppSync resolver invoked: {json.dumps(event)}")
    
    try:
        field = event.get('field')
        
        if field == 'errorRates':
            # Reuse existing function
            result = get_error_rates()
            logger.info("Error rates retrieved successfully")
            return result
        
        error_msg = f"Unknown field: {field}"
        logger.error(error_msg)
        return {"error": error_msg}
        
    except Exception as e:
        logger.error(f"Lambda handler error: {e}", exc_info=True)
        raise
