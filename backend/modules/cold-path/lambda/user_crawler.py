"""
GitHub User Crawler Lambda Function
Crawls GitHub users using the /users
endpoint and stores raw data in S3 as Parquet files
Uses AWS Lambda Powertools for observability
"""

import json
import os
import time
import uuid
from datetime import datetime, timezone
from io import BytesIO

import boto3
import pandas as pd
import requests
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit
from botocore.exceptions import ClientError

# AppSync client for publishing completion events
from utils.appsync_client import publish_crawler_completed
from utils.sentry_config import init_sentry

# Initialize Sentry
init_sentry()

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
DYNAMODB_TABLE_NAME = os.environ["DYNAMODB_TABLE_NAME"]
S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
REQUESTS_PER_EXECUTION = int(os.environ.get("REQUESTS_PER_EXECUTION", "700"))
SLEEP_INTERVAL = float(os.environ.get("SLEEP_INTERVAL", "0.1"))

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-user-crawler")
tracer = Tracer(service=f"{PROJECT_NAME}-user-crawler")
metrics = Metrics(namespace=f"{PROJECT_NAME.title()}/ColdPath", service="user-crawler")
metrics.add_dimension(name="CrawlerType", value="user")


# AWS clients
dynamodb = boto3.resource("dynamodb")
s3_client = boto3.client("s3")
eventbridge = boto3.client("events")

# GitHub API configuration
GITHUB_API_BASE = "https://api.github.com"
USERS_ENDPOINT = f"{GITHUB_API_BASE}/users"


@tracer.capture_method
def get_last_processed_id() -> int:
    """Read the last processed user ID from DynamoDB"""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        response = table.get_item(
            Key={"state_key": "user_bookmark"}, ConsistentRead=True
        )

        if "Item" in response:
            last_id = int(response["Item"].get("last_processed_id", 0))
            logger.info("Retrieved last processed ID", extra={"last_id": last_id})
            metrics.add_metric(
                name="LastProcessedId", unit=MetricUnit.Count, value=last_id
            )
            return last_id

        logger.warning("No bookmark found, starting from 0")
        return 0

    except ClientError as e:
        logger.error("Failed to read from DynamoDB", extra={"error": str(e)})
        raise


@tracer.capture_method
def update_bookmark(last_id: int, total_processed: int) -> None:
    """Synchronously update the bookmark in DynamoDB"""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        table.update_item(
            Key={"state_key": "user_bookmark"},
            UpdateExpression="SET last_processed_id = :lid, total_processed = :tp, updated_at = :ua",
            ExpressionAttributeValues={
                ":lid": last_id,
                ":tp": total_processed,
                ":ua": datetime.now(timezone.utc).isoformat(),
            },
        )
        logger.info(
            "Updated bookmark",
            extra={"last_id": last_id, "total_processed": total_processed},
        )
        metrics.add_metric(name="BookmarkUpdated", unit=MetricUnit.Count, value=1)

    except ClientError as e:
        logger.error("Failed to update DynamoDB bookmark", extra={"error": str(e)})
        raise


@tracer.capture_method
def save_to_s3_parquet(users: list[dict], start_id: int, end_id: int) -> dict:
    """Save data to S3 as Parquet with partitioning. Returns file metadata."""
    now = datetime.now(timezone.utc)
    year = now.year
    month = f"{now.month:02d}"
    day = f"{now.day:02d}"

    # Create S3 key with partitioning
    s3_key = f"cold-path/users/year={year}/month={month}/day={day}/users_{start_id:012d}_{end_id:012d}.parquet"

    try:
        # Flatten nested structures for Parquet
        flattened_users = []
        for user in users:
            flat_user = {
                "id": user.get("id"),
                "login": user.get("login"),
                "node_id": user.get("node_id"),
                "avatar_url": user.get("avatar_url"),
                "gravatar_id": user.get("gravatar_id"),
                "url": user.get("url"),
                "html_url": user.get("html_url"),
                "followers_url": user.get("followers_url"),
                "following_url": user.get("following_url"),
                "gists_url": user.get("gists_url"),
                "starred_url": user.get("starred_url"),
                "subscriptions_url": user.get("subscriptions_url"),
                "organizations_url": user.get("organizations_url"),
                "repos_url": user.get("repos_url"),
                "events_url": user.get("events_url"),
                "received_events_url": user.get("received_events_url"),
                "type": user.get("type"),
                "site_admin": user.get("site_admin"),
                "user_view_type": user.get("user_view_type"),
                "name": user.get("name"),
                "company": user.get("company"),
                "blog": user.get("blog"),
                "location": user.get("location"),
                "email": user.get("email"),
                "hireable": user.get("hireable"),
                "bio": user.get("bio"),
                "twitter_username": user.get("twitter_username"),
                "public_repos": user.get("public_repos"),
                "public_gists": user.get("public_gists"),
                "followers": user.get("followers"),
                "following": user.get("following"),
                "created_at": user.get("created_at"),
                "updated_at": user.get("updated_at"),
            }
            flattened_users.append(flat_user)

        # Convert to DataFrame
        df = pd.DataFrame(flattened_users)

        # Convert to Parquet in memory
        parquet_buffer = BytesIO()
        df.to_parquet(
            parquet_buffer,
            engine="pyarrow",
            compression="snappy",
            index=False,
        )
        parquet_buffer.seek(0)

        # Upload to S3
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=parquet_buffer.getvalue(),
            ContentType="application/octet-stream",
            Metadata={
                "start_id": str(start_id),
                "end_id": str(end_id),
                "count": str(len(users)),
                "format": "parquet",
                "compression": "snappy",
            },
        )

        logger.info(
            "Saved users to S3",
            extra={
                "count": len(users),
                "s3_key": s3_key,
                "size_bytes": len(parquet_buffer.getvalue()),
            },
        )
        metrics.add_metric(name="ItemsCrawled", unit=MetricUnit.Count, value=len(users))
        metrics.add_metric(name="UsersSaved", unit=MetricUnit.Count, value=len(users))
        metrics.add_metric(
            name="ParquetFileSize",
            unit=MetricUnit.Bytes,
            value=len(parquet_buffer.getvalue()),
        )

        return {
            "s3_key": s3_key,
            "size": len(parquet_buffer.getvalue()),
            "row_count": len(users),
        }

    except Exception as e:
        logger.error("Failed to write to S3", extra={"error": str(e), "s3_key": s3_key})
        metrics.add_metric(name="S3WriteErrors", unit=MetricUnit.Count, value=1)
        raise


def handle_response(response, retry_count, max_retries):
    if response.status_code == 200:
        metrics.add_metric(name="APIRequestsSuccess", unit=MetricUnit.Count, value=1)
        return response.json(), True, False
    if response.status_code == 403:
        logger.warning(
            "Rate limit exceeded",
            extra={"rate_limit_reset": response.headers.get("X-RateLimit-Reset")},
        )
        metrics.add_metric(name="RateLimitExceeded", unit=MetricUnit.Count, value=1)
        if retry_count < max_retries:
            backoff_time = 2**retry_count
            logger.info(
                "Retrying after backoff",
                extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
            )
            time.sleep(backoff_time)
            return None, False, True
        return None, True, False
    if response.status_code >= 500:
        logger.warning(
            "GitHub API server error", extra={"status_code": response.status_code}
        )
        metrics.add_metric(name="APIServerErrors", unit=MetricUnit.Count, value=1)
        if retry_count < max_retries:
            backoff_time = 2**retry_count
            logger.info(
                "Retrying after backoff",
                extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
            )
            time.sleep(backoff_time)
            return None, False, True
        return None, True, False
    logger.error(
        "Unexpected API response",
        extra={
            "status_code": response.status_code,
            "body": response.text[:500],
        },
    )
    metrics.add_metric(name="APIRequestsError", unit=MetricUnit.Count, value=1)
    return None, True, False


@tracer.capture_method
def fetch_users(
    since_id: int, github_token: str, max_retries: int = 3
) -> tuple[list[dict] | None, dict]:
    """
    Fetch users from GitHub API with exponential backoff retry
    Returns (list of users or None on error, request_metrics)
    """
    headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": f"{PROJECT_NAME}-Crawler",
    }

    url = f"{USERS_ENDPOINT}?since={since_id}&per_page=100"

    result = None
    request_metrics = {
        "since_id": since_id,
        "request_start": None,
        "request_end": None,
        "retrieval": 0,
        "status_code": 0,
        "rate_limit_remaining": 0,
        "rate_limit": 0,
        "rate_limit_reset": 0,
    }

    for retry_count in range(max_retries + 1):
        try:
            metrics.add_metric(name="APIRequests", unit=MetricUnit.Count, value=1)
            request_metrics["request_start"] = datetime.now(timezone.utc).isoformat()
            response = requests.get(url, headers=headers, timeout=30)
            request_metrics["request_end"] = datetime.now(timezone.utc).isoformat()
            request_metrics["status_code"] = response.status_code

            # Log rate limit info
            rate_limit_remaining = response.headers.get("X-RateLimit-Remaining")
            rate_limit = response.headers.get("X-RateLimit-Limit")
            rate_limit_reset = response.headers.get("X-RateLimit-Reset")

            request_metrics["rate_limit_remaining"] = int(rate_limit_remaining or 0)
            request_metrics["rate_limit"] = int(rate_limit or 0)
            request_metrics["rate_limit_reset"] = int(rate_limit_reset or 0)

            logger.info(
                "GitHub API response",
                extra={
                    "status_code": response.status_code,
                    "rate_limit_remaining": rate_limit_remaining,
                    "rate_limit_reset": rate_limit_reset,
                },
            )
            metrics.add_metric(
                name="RateLimitRemaining",
                unit=MetricUnit.Count,
                value=int(rate_limit_remaining or 0),
            )

            result, should_break, should_continue = handle_response(
                response, retry_count, max_retries
            )
            if should_break:
                break
            if should_continue:
                continue

        except requests.exceptions.Timeout:
            request_metrics["request_end"] = datetime.now(timezone.utc).isoformat()
            logger.warning("Request timeout")
            metrics.add_metric(name="APITimeouts", unit=MetricUnit.Count, value=1)
            if retry_count < max_retries:
                backoff_time = 2**retry_count
                logger.info(
                    "Retrying after backoff",
                    extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
                )
                time.sleep(backoff_time)
                continue
            break
        except requests.exceptions.RequestException as e:
            request_metrics["request_end"] = datetime.now(timezone.utc).isoformat()
            logger.error("Request failed", extra={"error": str(e)})
            metrics.add_metric(name="APIRequestsError", unit=MetricUnit.Count, value=1)
            if retry_count < max_retries:
                backoff_time = 2**retry_count
                logger.info(
                    "Retrying after backoff",
                    extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
                )
                time.sleep(backoff_time)
                continue
            break

    if result:
        request_metrics["retrieval"] = len(result)

    return result, request_metrics


@tracer.capture_method
def crawl_users(
    start_id: int, num_requests: int, github_token: str, context
) -> tuple[int, int, list[dict], list[dict]]:
    """
    Execute the crawl loop with pacing
    Returns (last_processed_id, total_users_fetched, request_metrics_list, s3_files_list)
    """
    current_id = start_id
    total_users = 0
    batch_users = []
    batch_start_id = start_id

    request_metrics_list = []
    s3_files_list = []

    for i in range(num_requests):
        # Check remaining time (stop 30 seconds before timeout)
        remaining_time = context.get_remaining_time_in_millis() / 1000
        if remaining_time < 30:
            logger.warning(
                "Approaching timeout, stopping early",
                extra={"request_number": i + 1, "total_requests": num_requests},
            )
            metrics.add_metric(
                name="EarlyStopDueToTimeout", unit=MetricUnit.Count, value=1
            )
            break

        # Fetch users
        users, req_metrics = fetch_users(current_id, github_token)
        request_metrics_list.append(req_metrics)

        if users is None:
            logger.warning("Failed to fetch users", extra={"current_id": current_id})
            time.sleep(SLEEP_INTERVAL)
            continue

        if len(users) == 0:
            logger.info("No more users returned, reached end of dataset")
            metrics.add_metric(name="DatasetEndReached", unit=MetricUnit.Count, value=1)
            break

        # Add to batch
        batch_users.extend(users)
        total_users += len(users)

        # Update current_id to the last user ID in this batch
        last_user_id = users[-1]["id"]
        current_id = last_user_id

        logger.debug(
            "Fetched batch",
            extra={
                "request_number": i + 1,
                "users_count": len(users),
                "last_id": last_user_id,
            },
        )

        # Save batch to S3 every 10 requests (approximately 1000 users)
        if (i + 1) % 10 == 0 and batch_users:
            file_meta = save_to_s3_parquet(batch_users, batch_start_id, current_id)
            s3_files_list.append(file_meta)
            batch_users = []
            batch_start_id = current_id + 1

        # Pace requests
        time.sleep(SLEEP_INTERVAL)

    # Save any remaining users in the batch
    if batch_users:
        file_meta = save_to_s3_parquet(batch_users, batch_start_id, current_id)
        s3_files_list.append(file_meta)

    metrics.add_metric(
        name="TotalUsersFetched", unit=MetricUnit.Count, value=total_users
    )
    return current_id, total_users, request_metrics_list, s3_files_list


@logger.inject_lambda_context(log_event=True)
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(_event, context):
    """
    Main Lambda handler
    """
    metrics.add_metric(name="CrawlerRuns", unit=MetricUnit.Count, value=1)
    logger.info(
        "Starting GitHub user crawler",
        extra={
            "requests_per_execution": REQUESTS_PER_EXECUTION,
            "sleep_interval": SLEEP_INTERVAL,
        },
    )

    try:
        if not GITHUB_TOKEN:
            logger.error("GITHUB_TOKEN environment variable not set.")
            raise ValueError("GitHub token is not configured.")

        # Get last processed ID
        start_id = get_last_processed_id()

        # Generate run_id
        run_id = str(uuid.uuid4())
        start_time = datetime.now(timezone.utc).isoformat()

        # Execute crawl
        last_id, total_fetched, requests_metrics, s3_files = crawl_users(
            start_id, REQUESTS_PER_EXECUTION, GITHUB_TOKEN, context
        )

        end_time = datetime.now(timezone.utc).isoformat()
        duration_ms = (
            datetime.fromisoformat(end_time) - datetime.fromisoformat(start_time)
        ).total_seconds() * 1000

        # Update bookmark
        if last_id > start_id:
            # Get current total from DynamoDB
            table = dynamodb.Table(DYNAMODB_TABLE_NAME)
            response = table.get_item(Key={"state_key": "user_bookmark"})
            current_total = int(response.get("Item", {}).get("total_processed", 0))
            new_total = current_total + total_fetched

            update_bookmark(last_id, new_total)

            logger.info(
                "Crawl complete",
                extra={
                    "run_id": run_id,
                    "start_id": start_id,
                    "end_id": last_id,
                    "users_fetched": total_fetched,
                    "total_processed": new_total,
                },
            )

            # Publish completion event to EventBridge
            try:
                event_payload = {
                    "run_id": run_id,
                    "crawler_type": "user",
                    "run_metadata": {
                        "retrieval": total_fetched,
                        "request_count": len(requests_metrics),
                        "duration_ms": duration_ms,
                        "start_time": start_time,
                        "end_time": end_time,
                    },
                    "bookmark": {
                        "last_processed_id": last_id,
                        "total_processed": new_total,
                    },
                    "requests": requests_metrics,
                    "s3_files": s3_files,
                }

                eventbridge.put_events(
                    Entries=[
                        {
                            "Source": f"{PROJECT_NAME}.crawler",
                            "DetailType": "CrawlerCompleted",
                            "Detail": json.dumps(event_payload),
                            "Time": datetime.now(timezone.utc),
                        }
                    ]
                )
                logger.info("Published crawler completion event to EventBridge")
                metrics.add_metric(
                    name="EventBridgePublishSuccess", unit=MetricUnit.Count, value=1
                )
            except Exception as e:
                logger.error(
                    "Failed to publish to EventBridge",
                    extra={"error": str(e)},
                )
                metrics.add_metric(
                    name="EventBridgePublishFailure", unit=MetricUnit.Count, value=1
                )

            # Publish completion event to AppSync (Legacy)
            try:
                publish_crawler_completed(
                    crawler_type="user",
                    start_id=start_id,
                    end_id=last_id,
                    items_fetched=total_fetched,
                    total_processed=new_total,
                    success=True,
                )
                logger.info("Published crawler completion event to AppSync")
            except Exception as e:
                logger.error(f"Failed to publish to AppSync: {e}")
                # Don't fail the crawler if AppSync publish fails

            return {
                "statusCode": 200,
                "body": {
                    "message": "Crawl completed successfully",
                    "run_id": run_id,
                    "start_id": start_id,
                    "end_id": last_id,
                    "users_fetched": total_fetched,
                    "total_processed": new_total,
                },
            }

        logger.warning("No progress made in this execution")
        metrics.add_metric(name="NoProgressMade", unit=MetricUnit.Count, value=1)
        return {
            "statusCode": 200,
            "body": {"message": "No progress made", "start_id": start_id},
        }

    except Exception:
        logger.exception("Fatal error in crawler")
        metrics.add_metric(name="FatalErrors", unit=MetricUnit.Count, value=1)
        raise
