import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit
from botocore.exceptions import ClientError

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

    last_processed_id = run_data.get("last_processed_id", 0)

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
def write_run_data(run_id: str, crawler_type: str, run_data: dict, s3_files: list):
    """
    Write run metadata to DynamoDB.
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
        "created_at": run_data.get("end_time", datetime.now(timezone.utc).isoformat()),
        "retrieval": run_data.get("retrieval", 0),
        "size": total_size,
        "request_count": run_data.get("request_count", 0),
        "duration_ms": run_data.get("duration_ms", 0),
    }

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
                "rate_limit_limit": req.get("rate_limit_limit", 0),
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
def publish_cloudwatch_metrics(crawler_type: str, run_data: dict, s3_files: list):
    """
    Publish operational metrics to CloudWatch.
    """
    total_size = sum(f.get("size", 0) for f in s3_files)

    metrics.add_metric(name="CrawlerRuns", unit=MetricUnit.Count, value=1)
    metrics.add_metric(
        name="ItemsProcessed", unit=MetricUnit.Count, value=run_data.get("retrieval", 0)
    )
    metrics.add_metric(name="S3StorageSize", unit=MetricUnit.Bytes, value=total_size)
    metrics.add_metric(
        name="RequestDuration",
        unit=MetricUnit.Milliseconds,
        value=run_data.get("duration_ms", 0),
    )

    # Add dimensions
    metrics.add_dimension(name="CrawlerType", value=crawler_type)


@logger.inject_lambda_context
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event, context):
    """
    Main handler for telemetry processing.
    """
    logger.info("Received event", extra={"event": event})

    try:
        detail = event.get("detail", {})
        crawler_type = detail.get("crawler_type")
        run_id = detail.get("run_id")

        if not crawler_type or not run_id:
            logger.warning("Missing crawler_type or run_id in event")
            return

        run_metadata = detail.get("run_metadata", {})
        bookmark_data = detail.get("bookmark", {})
        requests = detail.get("requests", [])
        s3_files = detail.get("s3_files", [])

        # Merge bookmark data into run_metadata for convenience
        run_metadata["last_processed_id"] = bookmark_data.get("last_processed_id")

        # 1. Update Bookmark
        update_bookmark(crawler_type, run_metadata, s3_files)

        # 2. Write Run Metadata
        write_run_data(run_id, crawler_type, run_metadata, s3_files)

        # 3. Write Request Data
        write_request_data(run_id, crawler_type, requests)

        # 4. Write S3 Data
        write_s3_data(run_id, crawler_type, s3_files)

        # 5. Publish Metrics
        publish_cloudwatch_metrics(crawler_type, run_metadata, s3_files)

        logger.info(f"Successfully processed telemetry for run {run_id}")

    except Exception:
        logger.exception("Error processing telemetry event")
        raise  # Raise to trigger DLQ
