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
from aws_lambda_powertools import Logger, Tracer
from botocore.exceptions import ClientError
from utils.crawler_utils import decode_state_key, get_crawler_config
from utils.sentry_config import init_sentry

# Initialize Sentry
init_sentry()

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
CRAWL_STATE_TABLE_NAME = os.environ["CRAWL_STATE_TABLE_NAME"]
S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-github-crawler")
tracer = Tracer(service=f"{PROJECT_NAME}-github-crawler")

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")
crawl_state_table = dynamodb.Table(CRAWL_STATE_TABLE_NAME)
s3_client = boto3.client("s3")
eventbridge = boto3.client("events")


def flatten_repository(repository: dict) -> dict:
    """Flatten repository data for Parquet"""
    return {
        "id": repository.get("id"),
        "node_id": repository.get("node_id"),
        "name": repository.get("name"),
        "full_name": repository.get("full_name"),
        "private": repository.get("private"),
        "owner_id": repository.get("owner", {}).get("id"),
        "owner_node_id": repository.get("owner", {}).get("node_id"),
        "description": repository.get("description"),
        "fork": repository.get("fork"),
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
    config: dict, items: list[dict], start_id: int, end_id: int
) -> dict:
    """Save data to S3 as Parquet with partitioning. Returns file metadata."""
    now = datetime.now(timezone.utc)
    year = now.year
    month = f"{now.month:02d}"
    day = f"{now.day:02d}"

    # Create S3 key with partitioning
    prefix = config["s3_prefix"]
    filename_prefix = config["organisation"] + "_" + config["entity"]
    s3_key = f"{prefix}/year={year}/month={month}/day={day}/{filename_prefix}_{start_id:012d}_{end_id:012d}.parquet"

    try:
        # Flatten nested structures based on type
        flattened_items = []
        for item in items:
            if config["entity"] == "repository":
                flattened_items.append(flatten_repository(item))
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
                "crawler_type": config["entity"],
            },
        )

        logger.info(
            "Saved to S3",
            extra={
                "count": len(items),
                "s3_key": s3_key,
                "size_bytes": len(parquet_buffer.getvalue()),
            },
        )

        return {
            "s3_key": s3_key,
            "size": len(parquet_buffer.getvalue()),
            "row_count": len(items),
        }

    except Exception as e:
        logger.error("Failed to write to S3", extra={"error": str(e), "s3_key": s3_key})
        raise


def handle_response(response, retry_count, max_retries):
    if response.status_code == 200:
        return response.json(), True, False
    if response.status_code == 403:
        logger.warning(
            "Rate limit exceeded",
            extra={"rate_limit_reset": response.headers.get("X-RateLimit-Reset")},
        )
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
        if retry_count < max_retries:
            backoff_time = 2**retry_count
            logger.info(
                "Retrying after backoff",
                extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
            )
            time.sleep(backoff_time)
            return None, False, True
        logger.info(
            "GitHub API server error",
            extra={"status_code": response.status_code, "body": response.text[:500]},
        )
        return None, True, False

    return None, True, False


@tracer.capture_method
def fetch_data(
    config: dict, since_id: int, github_token: str, max_retries: int = 3
) -> tuple[list[dict] | None, dict]:
    """
    Fetch data from GitHub API with exponential backoff retry
    Returns (list of items or None on error, request_metrics)
    """
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
        "rate_limit": 0,
        "rate_limit_reset": 0,
    }

    for retry_count in range(max_retries + 1):
        try:
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
    config: dict, start_id: int, num_requests: int, github_token: str, context
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
            logger.info(
                "Approaching timeout, stopping early",
                extra={"request_number": i + 1, "total_requests": num_requests},
            )
            break

        # Fetch data
        items, req_metrics = fetch_data(config, current_id, github_token)
        request_metrics_list.append(req_metrics)

        if items is None:
            logger.warning(
                f"Failed to fetch {config['entity']} items",
                extra={"current_id": current_id},
            )
            time.sleep(config["sleep_interval"])
            continue

        if len(items) == 0:
            logger.info("No more items returned, reached end of dataset")
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
                "last_processed_id": last_item_id,
            },
        )

        # Save batch to S3 every 10 requests (approximately 1000 items)
        if (i + 1) % 10 == 0 and batch_items:
            file_meta = save_to_s3_parquet(
                config, batch_items, batch_start_id, current_id
            )
            s3_files_list.append(file_meta)
            batch_items = []
            batch_start_id = current_id + 1

        # Pace requests
        time.sleep(config["sleep_interval"])

    # Save any remaining items in the batch
    if batch_items:
        file_meta = save_to_s3_parquet(config, batch_items, batch_start_id, current_id)
        s3_files_list.append(file_meta)

    return current_id, total_items, request_metrics_list, s3_files_list


@tracer.capture_method
def update_bookmark(
    state_key: str,
    last_processed_id: int,
    total_processed: int,
) -> dict:
    """Synchronously update the bookmark in DynamoDB"""

    # Validate state_key format
    organisation, entity = decode_state_key(state_key)

    if not crawl_state_table:
        raise ValueError("CRAWL_STATE_TABLE_NAME not configured")

    try:
        response = crawl_state_table.update_item(
            Key={"state_key": state_key},
            UpdateExpression="SET last_processed_id = :lid, total_processed = :tp, updated_at = :ua",
            ExpressionAttributeValues={
                ":lid": last_processed_id,
                ":tp": total_processed,
                ":ua": datetime.now(timezone.utc).isoformat(),
            },
            ReturnValues="UPDATED_NEW",
        )

        logger.info(
            f"Updated bookmark for {organisation}/{entity}",
            extra={
                "last_processed_id": last_processed_id,
                "total_processed": total_processed,
                "updated_attributes": response.get("Attributes"),
            },
        )

        return response

    except ClientError as e:
        logger.error("Failed to update DynamoDB bookmark", extra={"error": str(e)})
        raise


@logger.inject_lambda_context(log_event=True)
@tracer.capture_lambda_handler
def lambda_handler(event, context):
    """
    Main Lambda handler
    Expects event to contain "state_key" (encoded)
    """
    state_key = event.get("state_key")

    if not state_key:
        logger.error("Missing state_key in event")
        return {
            "statusCode": 400,
            "body": {"message": "Missing state_key in event"},
        }

    try:
        if not GITHUB_TOKEN:
            logger.error("GITHUB_TOKEN environment variable not set.")
            raise ValueError("GitHub token is not configured.")

        # Get configuration from DynamoDB
        config = get_crawler_config(state_key)

        # Use AWS request ID as run_id
        run_id = context.aws_request_id

        start_id = config["last_processed_id"]

        logger.info(f"Starting GitHub {config['entity']} crawler")

        # Execute crawl
        last_processed_id, total_fetched, requests_metrics, s3_files = crawl(
            config, start_id, config["requests_per_execution"], GITHUB_TOKEN, context
        )

        # Update bookmark
        if last_processed_id > start_id:
            new_total = config["total_processed"] + total_fetched
            update_bookmark(
                config["state_key"],
                last_processed_id,
                new_total,
            )

            logger.info(
                "Crawl complete",
                extra={
                    "run_id": run_id,
                    "start_id": start_id,
                    "last_processed_id": last_processed_id,
                    "items_fetched": total_fetched,
                    "total_processed": new_total,
                },
            )

            # Publish completion event to EventBridge
            try:
                # Save detailed metadata to S3 to avoid EventBridge 256KB limit
                now = datetime.now(timezone.utc)
                metadata_key = (
                    f"cold-path/github/telemetry/{config['entity']}/"
                    f"year={now.year}/month={now.month:02d}/day={now.day:02d}/"
                    f"{run_id}.json"
                )

                full_metadata = {
                    "run_id": run_id,
                    "function_name": context.function_name,
                    "crawler_type": config["entity"],
                    "run_metadata": {
                        "organisation": config["organisation"],
                        "entity": config["entity"],
                        "retrieval": total_fetched,
                        "request_count": len(requests_metrics),
                        "start_id": start_id,
                        "last_processed_id": last_processed_id,
                        "total_processed": new_total,
                    },
                    "requests": requests_metrics,
                    "s3_files": s3_files,
                }

                s3_client.put_object(
                    Bucket=S3_BUCKET_NAME,
                    Key=metadata_key,
                    Body=json.dumps(full_metadata),
                    ContentType="application/json",
                )

                # Send minimal EventBridge event
                event_payload = {
                    "run_id": run_id,
                    "metadata_s3_key": metadata_key,
                    "state_key": state_key,
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
            except Exception as e:
                logger.error(
                    "Failed to publish to EventBridge",
                    extra={"error": str(e)},
                )

            return {
                "statusCode": 200,
                "body": {
                    "message": "Crawl completed successfully",
                    "run_id": run_id,
                    "start_id": start_id,
                    "end_id": last_processed_id,
                    "items_fetched": total_fetched,
                    "total_processed": new_total,
                },
            }

        logger.warning("No progress made in this execution")
        return {
            "statusCode": 200,
            "body": {"message": "No progress made", "start_id": start_id},
        }

    except Exception:
        logger.exception("Fatal error in crawler")
        raise
