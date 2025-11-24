"""
AppSync HTTP client for publishing events from crawlers
Uses AWS Signature Version 4 for IAM authentication

This module provides functionality for crawler Lambda functions to publish
completion events to AWS AppSync GraphQL API with proper authentication,
retry logic, and error handling.
"""

import json
import os
import time

import boto3
import requests
from aws_lambda_powertools import Logger
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

# Environment variables
APPSYNC_ENDPOINT = os.environ.get("dashboard_appsync_api_url")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# Initialize logger
logger = Logger(service="appsync-client")

# GraphQL mutation for publishing crawler completion events
PUBLISH_CRAWLER_COMPLETED_MUTATION = """
mutation PublishCrawlerCompleted($input: CrawlerCompletedInput!) {
  publishCrawlerCompleted(input: $input) {
    crawlerType
    startId
    endId
    itemsFetched
    totalProcessed
    completedAt
    success
    errorMessage
  }
}
"""


def publish_crawler_completed(
    crawler_type: str,
    start_id: int,
    end_id: int,
    items_fetched: int,
    total_processed: int,
    success: bool = True,
    error_message: str | None = None,
    max_retries: int = 3,
) -> dict:
    """
    Publish crawler completion event to AppSync with retry logic

    Args:
        crawler_type: Type of crawler ("repo" or "user")
        start_id: Starting ID for this crawl execution
        end_id: Ending ID for this crawl execution
        items_fetched: Number of items fetched in this run
        total_processed: Total items processed across all runs
        success: Whether the crawl succeeded (default: True)
        error_message: Error message if failed (default: None)
        max_retries: Maximum number of retry attempts (default: 3)

    Returns:
        dict: Response from AppSync API

    Raises:
        ValueError: If dashboard_appsync_api_url is not configured
        Exception: If all retry attempts fail
    """

    if not APPSYNC_ENDPOINT:
        error_msg = "dashboard_appsync_api_url environment variable not set"
        logger.error(error_msg)
        raise ValueError(error_msg)

    # Prepare GraphQL request payload
    variables = {
        "input": {
            "crawlerType": crawler_type,
            "startId": start_id,
            "endId": end_id,
            "itemsFetched": items_fetched,
            "totalProcessed": total_processed,
            "success": success,
            "errorMessage": error_message,
        }
    }

    payload = {
        "query": PUBLISH_CRAWLER_COMPLETED_MUTATION,
        "variables": variables,
    }

    logger.info(
        "Publishing crawler completion event",
        extra={
            "crawler_type": crawler_type,
            "start_id": start_id,
            "end_id": end_id,
            "items_fetched": items_fetched,
            "total_processed": total_processed,
            "success": success,
        },
    )

    # Retry loop with exponential backoff
    last_exception = None

    for attempt in range(max_retries + 1):
        try:
            # Sign request with IAM credentials using SigV4
            session = boto3.Session()
            credentials = session.get_credentials()

            if not credentials:
                error_msg = "Unable to retrieve AWS credentials"
                logger.error(error_msg)
                raise ValueError(error_msg)

            # Create AWS request for signing
            request = AWSRequest(
                method="POST",
                url=APPSYNC_ENDPOINT,
                data=json.dumps(payload),
                headers={
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
            )

            # Add AWS Signature V4 authentication
            SigV4Auth(credentials, "appsync", AWS_REGION).add_auth(request)

            # Send HTTP request
            response = requests.post(
                APPSYNC_ENDPOINT,
                headers=dict(request.headers),
                data=request.body,
                timeout=30,
            )

            # Check response status
            if response.status_code == 200:
                response_data = response.json()

                # Check for GraphQL errors
                if "errors" in response_data:
                    logger.error(
                        "AppSync returned GraphQL errors",
                        extra={"errors": response_data["errors"]},
                    )
                    errors_json = json.dumps(response_data["errors"])
                    raise Exception(f"GraphQL errors: {errors_json}")

                logger.info(
                    "Successfully published crawler completion event",
                    extra={
                        "crawler_type": crawler_type,
                        "attempt": attempt + 1,
                    },
                )

                return response_data

            # Handle non-200 responses
            logger.warning(
                "AppSync request failed",
                extra={
                    "status_code": response.status_code,
                    "response_body": response.text[:500],
                    "attempt": attempt + 1,
                },
            )

            # Don't retry on client errors (4xx)
            if 400 <= response.status_code < 500:
                error_msg = (
                    f"AppSync request failed with status "
                    f"{response.status_code}: {response.text}"
                )
                logger.error(error_msg)
                raise Exception(error_msg)

            # Retry on server errors (5xx)
            last_exception = Exception(
                f"AppSync request failed with status "
                f"{response.status_code}: {response.text}"
            )

        except requests.exceptions.Timeout as e:
            logger.warning(
                "AppSync request timeout",
                extra={"attempt": attempt + 1, "error": str(e)},
            )
            last_exception = e

        except requests.exceptions.RequestException as e:
            logger.warning(
                "AppSync request exception",
                extra={"attempt": attempt + 1, "error": str(e)},
            )
            last_exception = e

        except Exception as e:
            # For unexpected errors, log and potentially retry
            logger.warning(
                "Unexpected error during AppSync request",
                extra={"attempt": attempt + 1, "error": str(e)},
            )
            last_exception = e

        # Exponential backoff before retry (except on last attempt)
        if attempt < max_retries:
            backoff_time = 2**attempt  # 1s, 2s, 4s
            logger.info(
                "Retrying AppSync request after backoff",
                extra={
                    "backoff_seconds": backoff_time,
                    "attempt": attempt + 1,
                    "max_retries": max_retries,
                },
            )
            time.sleep(backoff_time)

    # All retries exhausted
    error_msg = f"Failed to publish to AppSync after {max_retries + 1} attempts"
    logger.error(
        error_msg,
        extra={
            "crawler_type": crawler_type,
            "last_exception": str(last_exception),
        },
    )

    raise Exception(f"{error_msg}: {last_exception}")
