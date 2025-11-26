import json
import os
import re
import time
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit
from botocore.exceptions import ClientError
from utils.appsync_client import publish_crawler_completed

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
TELEMETRY_TABLE_NAME = os.environ["TELEMETRY_TABLE_NAME"]

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-github-telemetry")
tracer = Tracer(service=f"{PROJECT_NAME}-github-telemetry")
metrics = Metrics(
    namespace=f"{PROJECT_NAME.title()}/ColdPath", service="crawler-telemetry"
)

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")
telemetry_table = dynamodb.Table(TELEMETRY_TABLE_NAME)
cloudwatch = boto3.client("cloudwatch")
logs_client = boto3.client("logs")
s3_client = boto3.client("s3")


@tracer.capture_method
def get_lambda_execution_metrics(request_id: str, function_name: str) -> dict:
    """
    Query CloudWatch Logs to get Lambda REPORT metrics for a specific request.
    Since the crawler has already completed, the REPORT is already in logs.
    """

    log_group = f"/aws/lambda/{function_name}"

    try:
        # Filter for REPORT lines with this request_id
        # Use a small time window (last hour)
        start_time = int((time.time() - 3600) * 1000)

        response = logs_client.filter_log_events(
            logGroupName=log_group,
            filterPattern=f"REPORT RequestId: {request_id}",
            startTime=start_time,
            limit=1,
        )

        if not response.get("events"):
            logger.warning(f"No REPORT found for request {request_id}")
            return {}

        # Parse the REPORT line
        message = response["events"][0]["message"]

        # Extract metrics using regex
        duration_match = re.search(r"Duration: ([\d.]+) ms", message)
        billed_match = re.search(r"Billed Duration: (\d+) ms", message)
        memory_size_match = re.search(r"Memory Size: (\d+) MB", message)
        max_memory_match = re.search(r"Max Memory Used: (\d+) MB", message)
        init_match = re.search(r"Init Duration: ([\d.]+) ms", message)

        metrics = {
            "duration_ms": float(duration_match.group(1)) if duration_match else 0,
            "billed_duration_ms": int(billed_match.group(1)) if billed_match else 0,
            "memory_size_mb": int(memory_size_match.group(1))
            if memory_size_match
            else 0,
            "max_memory_used_mb": int(max_memory_match.group(1))
            if max_memory_match
            else 0,
            "init_duration_ms": float(init_match.group(1)) if init_match else None,
        }

        logger.info(f"Retrieved Lambda metrics for request {request_id}", extra=metrics)
        return metrics

    except Exception as e:
        logger.error(f"Failed to query CloudWatch Logs: {e}")
        return {}


@tracer.capture_method
def update_bookmark(crawler_type: str, run_data: dict, s3_files: list):
    """
    Atomically update the bookmark with cumulative stats.
    """
    pk = f"BOOKMARK#{crawler_type.upper()}"
    sk = "CURRENT"

    # Calculate increments
    inc_runs = 1
    inc_requests = run_data.get("request_count", 0)
    inc_processed = run_data.get("retrieval", 0)
    inc_size = sum(f.get("size", 0) for f in s3_files)

    last_processed_id = run_data.get("end_id", 0)

    try:
        telemetry_table.update_item(
            Key={"PK": pk, "SK": sk},
            UpdateExpression="""
                SET total_runs = if_not_exists(total_runs, :zero) + :inc_runs,
                    total_requests = if_not_exists(total_requests, :zero) + :inc_requests,
                    total_processed = if_not_exists(total_processed, :zero) + :inc_processed,
                    total_size = if_not_exists(total_size, :zero) + :inc_size,
                    last_processed_id = :last_id,
                    updated_at = :timestamp,
                    entity_type = :entity_type,
                    crawler_type = :crawler_type
            """,
            ExpressionAttributeValues={
                ":zero": 0,
                ":inc_runs": inc_runs,
                ":inc_requests": inc_requests,
                ":inc_processed": inc_processed,
                ":inc_size": inc_size,
                ":last_id": last_processed_id,
                ":timestamp": datetime.now(timezone.utc).isoformat(),
                ":entity_type": "bookmark",
                ":crawler_type": crawler_type,
            },
        )
        logger.info(f"Updated bookmark for {crawler_type}")
    except ClientError as e:
        logger.error(f"Failed to update bookmark: {e}")
        raise


@tracer.capture_method
def write_run_data(
    run_id: str,
    crawler_type: str,
    run_data: dict,
    s3_files: list,
    lambda_metrics: dict | None = None,
):
    """
    Write run metadata to DynamoDB, including Lambda execution metrics.
    """
    pk = f"RUN#{run_id}"
    sk = "METADATA"

    total_size = sum(f.get("size", 0) for f in s3_files)

    item = {
        "PK": pk,
        "SK": sk,
        "entity_type": "run",
        "run_id": run_id,
        "crawler_type": crawler_type,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "retrieval": run_data.get("retrieval", 0),
        "size": total_size,
        "request_count": run_data.get("request_count", 0),
    }

    # Add Lambda execution metrics if available (including duration)
    if lambda_metrics:
        item.update(
            {
                "duration_ms": lambda_metrics.get("duration_ms", 0),
                "billed_duration_ms": lambda_metrics.get("billed_duration_ms", 0),
                "memory_size_mb": lambda_metrics.get("memory_size_mb", 0),
                "max_memory_used_mb": lambda_metrics.get("max_memory_used_mb", 0),
                "init_duration_ms": lambda_metrics.get("init_duration_ms"),
            }
        )

    # Convert floats to Decimal for DynamoDB
    item = json.loads(json.dumps(item), parse_float=Decimal)

    try:
        telemetry_table.put_item(Item=item)
        logger.info(f"Saved run metadata for {run_id}")
    except ClientError as e:
        logger.error(f"Failed to save run metadata: {e}")
        raise


@tracer.capture_method
def write_request_data(run_id: str, crawler_type: str, requests: list):
    """
    Batch write request data to DynamoDB.
    """
    if not requests:
        return

    with telemetry_table.batch_writer() as batch:
        for req in requests:
            timestamp = req.get("request_start", datetime.now(timezone.utc).isoformat())
            pk = f"RUN#{run_id}"
            sk = f"REQUEST#{timestamp}"

            item = {
                "PK": pk,
                "SK": sk,
                "entity_type": "request",
                "run_id": run_id,
                "crawler_type": crawler_type,
                "created_at": timestamp,
                "since_id": req.get("since_id", 0),
                "request_start": req.get("request_start"),
                "request_end": req.get("request_end"),
                "retrieval": req.get("retrieval", 0),
                "status_code": req.get("status_code", 0),
                "rate_limit_remaining": req.get("rate_limit_remaining", 0),
                "rate_limit": req.get("rate_limit", 0),
                "rate_limit_reset": req.get("rate_limit_reset", 0),
            }

            # Convert floats to Decimal
            item = json.loads(json.dumps(item), parse_float=Decimal)
            batch.put_item(Item=item)

    logger.info(f"Saved {len(requests)} requests for run {run_id}")


@tracer.capture_method
def write_s3_data(run_id: str, crawler_type: str, s3_files: list):
    """
    Write S3 file metadata to DynamoDB.
    """
    if not s3_files:
        return

    with telemetry_table.batch_writer() as batch:
        for i, file in enumerate(s3_files):
            timestamp = datetime.now(timezone.utc).isoformat()
            # Add index to timestamp to ensure uniqueness if multiple files
            pk = f"RUN#{run_id}"
            sk = f"S3#{timestamp}#{i}"

            item = {
                "PK": pk,
                "SK": sk,
                "entity_type": "s3",
                "run_id": run_id,
                "crawler_type": crawler_type,
                "created_at": timestamp,
                "s3_key": file.get("s3_key"),
                "size": file.get("size", 0),
                "row_count": file.get("row_count", 0),
            }

            # Convert floats to Decimal
            item = json.loads(json.dumps(item), parse_float=Decimal)
            batch.put_item(Item=item)

    logger.info(f"Saved {len(s3_files)} S3 file records for run {run_id}")


@tracer.capture_method
def publish_cloudwatch_metrics(
    crawler_type: str,
    run_data: dict,
    s3_files: list,
    lambda_metrics: dict | None = None,
):
    """
    Publish operational metrics to CloudWatch.
    """
    total_size = sum(f.get("size", 0) for f in s3_files)

    metrics.add_metric(name="CrawlerRuns", unit=MetricUnit.Count, value=1)
    metrics.add_metric(
        name="ItemsProcessed", unit=MetricUnit.Count, value=run_data.get("retrieval", 0)
    )
    metrics.add_metric(name="S3StorageSize", unit=MetricUnit.Bytes, value=total_size)

    # Use CloudWatch duration if available, otherwise fall back to run_data
    duration = (
        lambda_metrics.get("duration_ms", 0)
        if lambda_metrics
        else run_data.get("duration_ms", 0)
    )
    metrics.add_metric(
        name="RequestDuration",
        unit=MetricUnit.Milliseconds,
        value=duration,
    )

    # Add dimensions
    metrics.add_dimension(name="CrawlerType", value=crawler_type)


@logger.inject_lambda_context
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event, _context):
    """
    Main handler for telemetry processing.
    Reads full metadata from S3 based on the S3 key in the EventBridge event.
    """
    logger.info("Received event", extra={"event": event})

    try:
        detail = event.get("detail", {})
        run_id = detail.get("run_id")
        metadata_s3_key = detail.get("metadata_s3_key")

        if not run_id or not metadata_s3_key:
            logger.warning("Missing run_id or metadata_s3_key in event")
            return

        # Read full metadata from S3
        logger.info(f"Reading metadata from S3: {metadata_s3_key}")
        s3_bucket = os.environ["S3_BUCKET_NAME"]

        try:
            response = s3_client.get_object(Bucket=s3_bucket, Key=metadata_s3_key)
            full_metadata = json.loads(response["Body"].read())
        except Exception as e:
            logger.error(f"Failed to read metadata from S3: {e}")
            raise

        # Extract data from S3 metadata
        crawler_type = full_metadata.get("crawler_type")
        function_name = full_metadata.get("function_name")
        run_metadata = full_metadata.get("run_metadata", {})
        requests = full_metadata.get("requests", [])
        s3_files = full_metadata.get("s3_files", [])

        # Query CloudWatch Logs for Lambda execution metrics (if function_name available)
        lambda_metrics = {}
        if function_name:
            lambda_metrics = get_lambda_execution_metrics(run_id, function_name)

        # 1. Update Bookmark
        update_bookmark(crawler_type, run_metadata, s3_files)

        # 2. Write Run Metadata (including Lambda metrics)
        write_run_data(run_id, crawler_type, run_metadata, s3_files, lambda_metrics)

        # 3. Write Request Data
        write_request_data(run_id, crawler_type, requests)

        # 4. Write S3 Data
        write_s3_data(run_id, crawler_type, s3_files)

        # 5. Publish Metrics
        publish_cloudwatch_metrics(crawler_type, run_metadata, s3_files, lambda_metrics)

        # 6. Publish to AppSync for real-time frontend updates
        try:
            publish_crawler_completed(
                crawler_type=crawler_type,
                start_id=run_metadata.get("start_id", 0),
                end_id=run_metadata.get("end_id", 0),
                items_fetched=run_metadata.get("retrieval", 0),
                total_processed=run_metadata.get("total_processed", 0),
            )
            logger.info("Published crawler completion event to AppSync")
        except Exception as e:
            logger.error(f"Failed to publish to AppSync: {e}")
            # Don't raise - AppSync is not critical

        logger.info(f"Successfully processed telemetry for run {run_id}")

    except Exception:
        logger.exception("Error processing telemetry event")
        raise  # Raise to trigger DLQ
