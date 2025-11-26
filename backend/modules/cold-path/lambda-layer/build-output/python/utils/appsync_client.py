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
from datetime import datetime, timezone

import boto3
import requests
from aws_lambda_powertools import Logger
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

# Environment variables
DASHBOARD_APPSYNC_API_URL = os.environ.get("DASHBOARD_APPSYNC_API_URL")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# Initialize logger
logger = Logger(service="appsync-client")


def publish_crawler_completed(
    organisation: str,
    entity: str,
    items_fetched: int,
    total_processed: int,
    last_processed_id: int,
    max_retries: int = 3,
) -> dict:
    """
    Publish crawler completion event to AppSync with retry logic

    Args:
        organisation: Organisation name (e.g. "github")
        entity: Entity type (e.g. "repository", "user")
        items_fetched: Number of items fetched in this run
        total_processed: Total items processed across all runs
        last_processed_id: Last processed ID
        max_retries: Maximum number of retry attempts (default: 3)

    Returns:
        dict: Response from AppSync API
    """
    mutation = """
    mutation PublishCrawlerCompleted($input: CrawlerCompletedInput!) {
        publishCrawlerCompleted(input: $input) {
            organisation
            entity
            itemsFetched
            totalProcessed
            lastProcessedId
            updatedAt
        }
    }
    """

    variables = {
        "input": {
            "organisation": organisation,
            "entity": entity,
            "itemsFetched": items_fetched,
            "totalProcessed": total_processed,
            "lastProcessedId": last_processed_id,
            "updatedAt": datetime.now(timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
        }
    }

    logger.info(
        "Publishing crawler completion event",
        extra={
            "organisation": organisation,
            "entity": entity,
            "items_fetched": items_fetched,
            "total_processed": total_processed,
        },
    )

    return execute_graphql(mutation, variables, max_retries)


def execute_graphql(query: str, variables: dict, max_retries: int = 3) -> dict:
    """
    Executes a GraphQL query against the AppSync API with retry logic and SigV4 authentication.
    """
    if not DASHBOARD_APPSYNC_API_URL:
        error_msg = "dashboard_appsync_api_url environment variable not set"
        logger.error(error_msg)
        raise ValueError(error_msg)

    payload = {
        "query": query,
        "variables": variables,
    }

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
                url=DASHBOARD_APPSYNC_API_URL,
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
                DASHBOARD_APPSYNC_API_URL,
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
                    "Successfully executed GraphQL request",
                    extra={
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
            "last_exception": str(last_exception),
        },
    )

    raise Exception(f"{error_msg}: {last_exception}")
