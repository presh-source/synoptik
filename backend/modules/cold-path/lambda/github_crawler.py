"""
Unified GitHub Crawler Lambda Function
Crawls GitHub repositories or users based on input event
Stores raw data in S3 as Parquet files
Uses AWS Lambda Powertools for observability
"""

import json
import os
import time
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

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
CRAWL_STATE_TABLE_NAME = os.environ["CRAWL_STATE_TABLE_NAME"]
S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
REQUESTS_PER_EXECUTION = int(os.environ.get("REQUESTS_PER_EXECUTION", "700"))
SLEEP_INTERVAL = float(os.environ.get("SLEEP_INTERVAL", "0.1"))

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-github-crawler")
tracer = Tracer(service=f"{PROJECT_NAME}-github-crawler")
metrics = Metrics(
    namespace=f"{PROJECT_NAME.title()}/ColdPath", service="github-crawler"
)

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")
crawl_state_table = dynamodb.Table("CRAWL_STATE_TABLE_NAME")
s3_client = boto3.client("s3")
eventbridge = boto3.client("events")

# GitHub API configuration
GITHUB_API_BASE = "https://api.github.com"

# Configuration mapping
CRAWLER_CONFIG = {
    "repo": {
        "endpoint": f"{GITHUB_API_BASE}/repositories",
        "bookmark_key": "repo_bookmark",
        "s3_prefix": "cold-path/github/repositories",
        "entity_name": "repositories",
    },
    "user": {
        "endpoint": f"{GITHUB_API_BASE}/users",
        "bookmark_key": "user_bookmark",
        "s3_prefix": "cold-path/github/users",
        "entity_name": "users",
    },
}


@tracer.capture_method
def get_last_processed_id(crawler_type: str) -> int:
    """Read the last processed ID from DynamoDB for the specific crawler type"""
    config = CRAWLER_CONFIG.get(crawler_type)
    if not config:
        raise ValueError(f"Invalid crawler type: {crawler_type}")

    try:
        response = crawl_state_table.get_item(
            Key={"state_key": config["bookmark_key"]}, ConsistentRead=True
        )

        if "Item" in response:
            last_id = int(response["Item"].get("last_processed_id", 0))
            logger.info(
                f"Retrieved last processed ID for {crawler_type}",
                extra={"last_id": last_id},
            )
            metrics.add_metric(
                name="LastProcessedId", unit=MetricUnit.Count, value=last_id
            )
            return last_id

        logger.warning(f"No bookmark found for {crawler_type}, starting from 0")
        return 0

    except ClientError as e:
        logger.error("Failed to read from DynamoDB", extra={"error": str(e)})
        raise


@tracer.capture_method
def update_bookmark(crawler_type: str, last_id: int, total_processed: int) -> None:
    """Synchronously update the bookmark in DynamoDB"""
    config = CRAWLER_CONFIG.get(crawler_type)
    if not config:
        raise ValueError(f"Invalid crawler type: {crawler_type}")

    try:
        crawl_state_table.update_item(
            Key={"state_key": config["bookmark_key"]},
            UpdateExpression="SET last_processed_id = :lid, total_processed = :tp, updated_at = :ua",
            ExpressionAttributeValues={
                ":lid": last_id,
                ":tp": total_processed,
                ":ua": datetime.now(timezone.utc).isoformat(),
            },
        )
        logger.info(
            f"Updated bookmark for {crawler_type}",
            extra={"last_id": last_id, "total_processed": total_processed},
        )
        metrics.add_metric(name="BookmarkUpdated", unit=MetricUnit.Count, value=1)

    except ClientError as e:
        logger.error("Failed to update DynamoDB bookmark", extra={"error": str(e)})
        raise


def flatten_repo(repo: dict) -> dict:
    """Flatten repository data for Parquet"""
    return {
        "id": repo.get("id"),
        "node_id": repo.get("node_id"),
        "name": repo.get("name"),
        "full_name": repo.get("full_name"),
        "private": repo.get("private"),
        "owner_id": repo.get("owner", {}).get("id"),
        "owner_node_id": repo.get("owner", {}).get("node_id"),
        "description": repo.get("description"),
        "fork": repo.get("fork"),
    }


def flatten_user(user: dict) -> dict:
    """Flatten user data for Parquet"""
    return {
        "id": user.get("id"),
        "login": user.get("login"),
        "node_id": user.get("node_id"),
        "avatar_url": user.get("avatar_url"),
        "gravatar_id": user.get("gravatar_id"),
        "url": user.get("url"),
        "html_url": user.get("html_url"),
        "type": user.get("type"),
        "user_view_type": user.get("user_view_type"),
        "site_admin": user.get("site_admin"),
    }


@tracer.capture_method
def save_to_s3_parquet(
    crawler_type: str, items: list[dict], start_id: int, end_id: int
) -> dict:
    """Save data to S3 as Parquet with partitioning. Returns file metadata."""
    config = CRAWLER_CONFIG.get(crawler_type)
    if not config:
        raise ValueError(f"Invalid crawler type: {crawler_type}")

    now = datetime.now(timezone.utc)
    year = now.year
    month = f"{now.month:02d}"
    day = f"{now.day:02d}"

    # Create S3 key with partitioning
    # Repo: cold-path/year=.../repos_...
    # User: cold-path/users/year=.../users_...
    prefix = config["s3_prefix"]
    filename_prefix = "repos" if crawler_type == "repo" else "users"
    s3_key = f"{prefix}/year={year}/month={month}/day={day}/{filename_prefix}_{start_id:012d}_{end_id:012d}.parquet"

    try:
        # Flatten nested structures based on type
        flattened_items = []
        for item in items:
            if crawler_type == "repo":
                flattened_items.append(flatten_repo(item))
            else:
                flattened_items.append(flatten_user(item))

        # Convert to DataFrame
        df = pd.DataFrame(flattened_items)

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
                "count": str(len(items)),
                "format": "parquet",
                "compression": "snappy",
                "crawler_type": crawler_type,
            },
        )

        logger.info(
            f"Saved {crawler_type} data to S3",
            extra={
                "count": len(items),
                "s3_key": s3_key,
                "size_bytes": len(parquet_buffer.getvalue()),
            },
        )
        metrics.add_metric(name="ItemsCrawled", unit=MetricUnit.Count, value=len(items))
        metrics.add_metric(name="FilesSaved", unit=MetricUnit.Count, value=1)
        metrics.add_metric(
            name="ParquetFileSize",
            unit=MetricUnit.Bytes,
            value=len(parquet_buffer.getvalue()),
        )

        return {
            "s3_key": s3_key,
            "size": len(parquet_buffer.getvalue()),
            "row_count": len(items),
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
def fetch_data(
    crawler_type: str, since_id: int, github_token: str, max_retries: int = 3
) -> tuple[list[dict] | None, dict]:
    """
    Fetch data from GitHub API with exponential backoff retry
    Returns (list of items or None on error, request_metrics)
    """
    config = CRAWLER_CONFIG.get(crawler_type)
    if not config:
        raise ValueError(f"Invalid crawler type: {crawler_type}")

    headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": f"{PROJECT_NAME}-GithubCrawler",
    }

    url = f"{config['endpoint']}?since={since_id}&per_page=100"

    result = None
    request_metrics = {
        "since_id": since_id,
        "request_start": None,
        "request_end": None,
        "retrieval": 0,
        "status_code": 0,
        "rate_limit_remaining": 0,
        "rate_limit_limit": 0,
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
            rate_limit_limit = response.headers.get("X-RateLimit-Limit")
            rate_limit_reset = response.headers.get("X-RateLimit-Reset")

            request_metrics["rate_limit_remaining"] = int(rate_limit_remaining or 0)
            request_metrics["rate_limit_limit"] = int(rate_limit_limit or 0)
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
def crawl(
    crawler_type: str, start_id: int, num_requests: int, github_token: str, context
) -> tuple[int, int, list[dict], list[dict]]:
    """
    Execute the crawl loop with pacing
    Returns (last_processed_id, total_items_fetched, request_metrics_list, s3_files_list)
    """
    current_id = start_id
    total_items = 0
    batch_items = []
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

        # Fetch data
        items, req_metrics = fetch_data(crawler_type, current_id, github_token)
        request_metrics_list.append(req_metrics)

        if items is None:
            logger.warning(
                f"Failed to fetch {crawler_type} items",
                extra={"current_id": current_id},
            )
            time.sleep(SLEEP_INTERVAL)
            continue

        if len(items) == 0:
            logger.info("No more items returned, reached end of dataset")
            metrics.add_metric(name="DatasetEndReached", unit=MetricUnit.Count, value=1)
            break

        # Add to batch
        batch_items.extend(items)
        total_items += len(items)

        # Update current_id to the last item ID in this batch
        last_item_id = items[-1]["id"]
        current_id = last_item_id

        logger.debug(
            "Fetched batch",
            extra={
                "request_number": i + 1,
                "items_count": len(items),
                "last_id": last_item_id,
            },
        )

        # Save batch to S3 every 10 requests (approximately 1000 items)
        if (i + 1) % 10 == 0 and batch_items:
            file_meta = save_to_s3_parquet(
                crawler_type, batch_items, batch_start_id, current_id
            )
            s3_files_list.append(file_meta)
            batch_items = []
            batch_start_id = current_id + 1

        # Pace requests
        time.sleep(SLEEP_INTERVAL)

    # Save any remaining items in the batch
    if batch_items:
        file_meta = save_to_s3_parquet(
            crawler_type, batch_items, batch_start_id, current_id
        )
        s3_files_list.append(file_meta)

    metrics.add_metric(
        name="TotalItemsFetched", unit=MetricUnit.Count, value=total_items
    )
    return current_id, total_items, request_metrics_list, s3_files_list


@logger.inject_lambda_context(log_event=True)
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event, context):
    """
    Main Lambda handler
    Expects event to contain "crawler_type": "repo" or "user"
    """
    crawler_type = event.get("crawler_type", "repo")  # Default to repo for safety

    if crawler_type not in CRAWLER_CONFIG:
        logger.error(f"Invalid crawler type: {crawler_type}")
        return {
            "statusCode": 400,
            "body": {"message": f"Invalid crawler type: {crawler_type}"},
        }

    # Set metric dimension
    metrics.add_dimension(name="CrawlerType", value=crawler_type)
    metrics.add_metric(name="CrawlerRuns", unit=MetricUnit.Count, value=1)

    logger.info(
        f"Starting GitHub {crawler_type} crawler",
        extra={
            "requests_per_execution": REQUESTS_PER_EXECUTION,
            "sleep_interval": SLEEP_INTERVAL,
            "crawler_type": crawler_type,
        },
    )

    try:
        if not GITHUB_TOKEN:
            logger.error("GITHUB_TOKEN environment variable not set.")
            raise ValueError("GitHub token is not configured.")

        # Get last processed ID
        start_id = get_last_processed_id(crawler_type)

        # Use AWS request ID as run_id
        run_id = context.aws_request_id
        start_time = datetime.now(timezone.utc).isoformat()

        # Execute crawl
        last_id, total_fetched, requests_metrics, s3_files = crawl(
            crawler_type, start_id, REQUESTS_PER_EXECUTION, GITHUB_TOKEN, context
        )

        end_time = datetime.now(timezone.utc).isoformat()
        duration_ms = (
            datetime.fromisoformat(end_time) - datetime.fromisoformat(start_time)
        ).total_seconds() * 1000

        # Update bookmark
        if last_id > start_id:
            # Get current total from DynamoDB
            config = CRAWLER_CONFIG[crawler_type]
            response = crawl_state_table.get_item(
                Key={"state_key": config["bookmark_key"]}
            )
            current_total = int(response.get("Item", {}).get("total_processed", 0))
            new_total = current_total + total_fetched

            update_bookmark(crawler_type, last_id, new_total)

            logger.info(
                "Crawl complete",
                extra={
                    "run_id": run_id,
                    "start_id": start_id,
                    "end_id": last_id,
                    "items_fetched": total_fetched,
                    "total_processed": new_total,
                },
            )

            # Publish completion event to EventBridge
            try:
                event_payload = {
                    "run_id": run_id,
                    "crawler_type": crawler_type,
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
                    crawler_type=crawler_type,
                    start_id=start_id,
                    end_id=last_id,
                    items_fetched=total_fetched,
                    total_processed=new_total,
                    success=True,
                )
                logger.info("Published crawler completion event to AppSync")
                metrics.add_metric(
                    name="AppSyncPublishSuccess", unit=MetricUnit.Count, value=1
                )
            except Exception as e:
                logger.error(
                    "Failed to publish to AppSync",
                    extra={"error": str(e)},
                )
                metrics.add_metric(
                    name="AppSyncPublishFailure", unit=MetricUnit.Count, value=1
                )

            return {
                "statusCode": 200,
                "body": {
                    "message": "Crawl completed successfully",
                    "run_id": run_id,
                    "start_id": start_id,
                    "end_id": last_id,
                    "items_fetched": total_fetched,
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
