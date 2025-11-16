"""
GitHub Repository Crawler Lambda Function
Crawls GitHub repositories using the /repositories
endpoint and stores raw data in S3 as Parquet files
Uses AWS Lambda Powertools for observability
"""

import time
import os
from datetime import datetime, timezone
from typing import Dict, List, Optional
import boto3
from botocore.exceptions import ClientError
import requests
import pandas as pd
from io import BytesIO

# AWS Lambda Powertools
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.metrics import MetricUnit

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
DYNAMODB_TABLE_NAME = os.environ["DYNAMODB_TABLE_NAME"]
S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
REQUESTS_PER_EXECUTION = int(os.environ.get("REQUESTS_PER_EXECUTION", "1000"))
SLEEP_INTERVAL = float(os.environ.get("SLEEP_INTERVAL", "0.8"))

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-crawler")
tracer = Tracer(service=f"{PROJECT_NAME}-crawler")
metrics = Metrics(namespace=f"{PROJECT_NAME.title()}/ColdPath", service="crawler")

# AWS clients
dynamodb = boto3.resource("dynamodb")
s3_client = boto3.client("s3")

# GitHub API configuration
GITHUB_API_BASE = "https://api.github.com"
REPOSITORIES_ENDPOINT = f"{GITHUB_API_BASE}/repositories"


@tracer.capture_method
def get_last_processed_id() -> int:
    """Read the last processed repository ID from DynamoDB"""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        response = table.get_item(Key={"state_key": "bookmark"}, ConsistentRead=True)

        if "Item" in response:
            last_id = int(response["Item"].get("last_processed_id", 0))
            logger.info("Retrieved last processed ID", extra={"last_id": last_id})
            metrics.add_metric(
                name="LastProcessedId", unit=MetricUnit.Count, value=last_id
            )
            return last_id
        else:
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
            Key={"state_key": "bookmark"},
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
def save_to_s3_parquet(repositories: List[Dict], start_id: int, end_id: int) -> None:
    """Save data to S3 as Parquet with partitioning"""
    now = datetime.now(timezone.utc)
    year = now.year
    month = f"{now.month:02d}"
    day = f"{now.day:02d}"

    # Create S3 key with partitioning
    s3_key = f"cold-path/year={year}/month={month}/day={day}/repos_{start_id:012d}_{end_id:012d}.parquet"

    try:
        # Flatten nested structures for Parquet
        flattened_repos = []
        for repo in repositories:
            flat_repo = {
                "id": repo.get("id"),
                "node_id": repo.get("node_id"),
                "name": repo.get("name"),
                "full_name": repo.get("full_name"),
                "private": repo.get("private"),
                "owner_id": repo.get("owner", {}).get("id"),
                "owner_login": repo.get("owner", {}).get("login"),
                "owner_type": repo.get("owner", {}).get("type"),
                "html_url": repo.get("html_url"),
                "description": repo.get("description"),
                "fork": repo.get("fork"),
                "url": repo.get("url"),
                "created_at": repo.get("created_at"),
                "updated_at": repo.get("updated_at"),
                "pushed_at": repo.get("pushed_at"),
                "homepage": repo.get("homepage"),
                "size": repo.get("size"),
                "stargazers_count": repo.get("stargazers_count"),
                "watchers_count": repo.get("watchers_count"),
                "language": repo.get("language"),
                "forks_count": repo.get("forks_count"),
                "open_issues_count": repo.get("open_issues_count"),
                "default_branch": repo.get("default_branch"),
                "score": repo.get("score"),
                "has_issues": repo.get("has_issues"),
                "has_projects": repo.get("has_projects"),
                "has_downloads": repo.get("has_downloads"),
                "has_wiki": repo.get("has_wiki"),
                "has_pages": repo.get("has_pages"),
                "license_name": repo.get("license", {}).get("name")
                if repo.get("license")
                else None,
                "license_key": repo.get("license", {}).get("key")
                if repo.get("license")
                else None,
            }
            flattened_repos.append(flat_repo)

        # Convert to DataFrame
        df = pd.DataFrame(flattened_repos)

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
                "count": str(len(repositories)),
                "format": "parquet",
                "compression": "snappy",
            },
        )

        logger.info(
            "Saved repositories to S3",
            extra={
                "count": len(repositories),
                "s3_key": s3_key,
                "size_bytes": len(parquet_buffer.getvalue()),
            },
        )
        metrics.add_metric(
            name="RepositoriesSaved", unit=MetricUnit.Count, value=len(repositories)
        )
        metrics.add_metric(
            name="ParquetFileSize",
            unit=MetricUnit.Bytes,
            value=len(parquet_buffer.getvalue()),
        )

    except Exception as e:
        logger.error("Failed to write to S3", extra={"error": str(e), "s3_key": s3_key})
        metrics.add_metric(name="S3WriteErrors", unit=MetricUnit.Count, value=1)
        raise


@tracer.capture_method
def fetch_repositories(
    since_id: int, github_token: str, retry_count: int = 0, max_retries: int = 3
) -> Optional[List[Dict]]:
    """
    Fetch repositories from GitHub API with exponential backoff retry
    Returns list of repositories or None on error
    """
    headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": f"{PROJECT_NAME}-Crawler",
    }

    url = f"{REPOSITORIES_ENDPOINT}?since={since_id}&per_page=100"

    try:
        response = requests.get(url, headers=headers, timeout=30)

        # Log rate limit info
        rate_limit_remaining = response.headers.get("X-RateLimit-Remaining")
        rate_limit_reset = response.headers.get("X-RateLimit-Reset")
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

        if response.status_code == 200:
            metrics.add_metric(
                name="APIRequestsSuccess", unit=MetricUnit.Count, value=1
            )
            return response.json()
        elif response.status_code == 403:
            logger.warning(
                "Rate limit exceeded", extra={"rate_limit_reset": rate_limit_reset}
            )
            metrics.add_metric(name="RateLimitExceeded", unit=MetricUnit.Count, value=1)
            # Exponential backoff for rate limit
            if retry_count < max_retries:
                backoff_time = 2**retry_count
                logger.info(
                    "Retrying after backoff",
                    extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
                )
                time.sleep(backoff_time)
                return fetch_repositories(
                    since_id, github_token, retry_count + 1, max_retries
                )
            return None
        elif response.status_code >= 500:
            logger.warning(
                "GitHub API server error", extra={"status_code": response.status_code}
            )
            metrics.add_metric(name="APIServerErrors", unit=MetricUnit.Count, value=1)
            # Exponential backoff for server errors
            if retry_count < max_retries:
                backoff_time = 2**retry_count
                logger.info(
                    "Retrying after backoff",
                    extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
                )
                time.sleep(backoff_time)
                return fetch_repositories(
                    since_id, github_token, retry_count + 1, max_retries
                )
            return None
        else:
            logger.error(
                "Unexpected API response",
                extra={
                    "status_code": response.status_code,
                    "body": response.text[:500],
                },
            )
            metrics.add_metric(name="APIRequestsError", unit=MetricUnit.Count, value=1)
            return None

    except requests.exceptions.Timeout:
        logger.warning("Request timeout")
        metrics.add_metric(name="APITimeouts", unit=MetricUnit.Count, value=1)
        # Retry on timeout
        if retry_count < max_retries:
            backoff_time = 2**retry_count
            logger.info(
                "Retrying after backoff",
                extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
            )
            time.sleep(backoff_time)
            return fetch_repositories(
                since_id, github_token, retry_count + 1, max_retries
            )
        return None
    except requests.exceptions.RequestException as e:
        logger.error("Request failed", extra={"error": str(e)})
        metrics.add_metric(name="APIRequestsError", unit=MetricUnit.Count, value=1)
        # Retry on network errors
        if retry_count < max_retries:
            backoff_time = 2**retry_count
            logger.info(
                "Retrying after backoff",
                extra={"backoff_seconds": backoff_time, "attempt": retry_count + 1},
            )
            time.sleep(backoff_time)
            return fetch_repositories(
                since_id, github_token, retry_count + 1, max_retries
            )
        return None


@tracer.capture_method
def crawl_repositories(
    start_id: int, num_requests: int, github_token: str, context
) -> tuple[int, int]:
    """
    Execute the crawl loop with pacing
    Returns (last_processed_id, total_repos_fetched)
    """
    current_id = start_id
    total_repos = 0
    batch_repos = []
    batch_start_id = start_id

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

        # Fetch repositories
        repos = fetch_repositories(current_id, github_token)

        if repos is None:
            logger.warning(
                "Failed to fetch repositories", extra={"current_id": current_id}
            )
            time.sleep(SLEEP_INTERVAL)
            continue

        if len(repos) == 0:
            logger.info("No more repositories returned, reached end of dataset")
            metrics.add_metric(name="DatasetEndReached", unit=MetricUnit.Count, value=1)
            break

        # Add to batch
        batch_repos.extend(repos)
        total_repos += len(repos)

        # Update current_id to the last repo ID in this batch
        last_repo_id = repos[-1]["id"]
        current_id = last_repo_id

        logger.debug(
            "Fetched batch",
            extra={
                "request_number": i + 1,
                "repos_count": len(repos),
                "last_id": last_repo_id,
            },
        )

        # Save batch to S3 every 10 requests (approximately 1000 repos)
        if (i + 1) % 10 == 0 and batch_repos:
            save_to_s3_parquet(batch_repos, batch_start_id, current_id)
            batch_repos = []
            batch_start_id = current_id + 1

        # Pace requests
        time.sleep(SLEEP_INTERVAL)

    # Save any remaining repos in the batch
    if batch_repos:
        save_to_s3_parquet(batch_repos, batch_start_id, current_id)

    metrics.add_metric(
        name="TotalRepositoriesFetched", unit=MetricUnit.Count, value=total_repos
    )
    return current_id, total_repos


@logger.inject_lambda_context(log_event=True)
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event, context):
    """
    Main Lambda handler
    """
    logger.info(
        "Starting GitHub repository crawler",
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

        # Execute crawl
        last_id, total_fetched = crawl_repositories(
            start_id, REQUESTS_PER_EXECUTION, GITHUB_TOKEN, context
        )

        # Update bookmark
        if last_id > start_id:
            # Get current total from DynamoDB
            table = dynamodb.Table(DYNAMODB_TABLE_NAME)
            response = table.get_item(Key={"state_key": "bookmark"})
            current_total = int(response.get("Item", {}).get("total_processed", 0))
            new_total = current_total + total_fetched

            update_bookmark(last_id, new_total)

            logger.info(
                "Crawl complete",
                extra={
                    "start_id": start_id,
                    "end_id": last_id,
                    "repositories_fetched": total_fetched,
                    "total_processed": new_total,
                },
            )

            return {
                "statusCode": 200,
                "body": {
                    "message": "Crawl completed successfully",
                    "start_id": start_id,
                    "end_id": last_id,
                    "repositories_fetched": total_fetched,
                    "total_processed": new_total,
                },
            }
        else:
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
