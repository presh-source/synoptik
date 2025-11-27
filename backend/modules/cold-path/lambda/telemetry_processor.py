import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from aws_lambda_powertools import Logger, Tracer
from botocore.exceptions import ClientError
from utils.appsync_client import publish_crawler_completed
from utils.crawler_utils import decode_state_key
from utils.sentry_config import init_sentry

# Initialize Sentry
init_sentry()

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
TELEMETRY_TABLE_NAME = os.environ["TELEMETRY_TABLE_NAME"]

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-telemetry")
tracer = Tracer(service=f"{PROJECT_NAME}-telemetry")

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")
telemetry_table = dynamodb.Table(TELEMETRY_TABLE_NAME)
cloudwatch = boto3.client("cloudwatch")
logs_client = boto3.client("logs")
s3_client = boto3.client("s3")


@tracer.capture_method
def update_bookmark(organisation: str, entity: str, run_data: dict, s3_files: list):
    """
    Atomically update the bookmark with cumulative stats.
    """
    pk = f"BOOKMARK#{organisation}#{entity}"
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
                    last_run_retrieval = :inc_processed,
                    updated_at = :timestamp,
                    organisation = :organisation,
                    entity = :entity
            """,
            ExpressionAttributeValues={
                ":zero": 0,
                ":inc_runs": inc_runs,
                ":inc_requests": inc_requests,
                ":inc_processed": inc_processed,
                ":inc_size": inc_size,
                ":last_id": last_processed_id,
                ":timestamp": datetime.now(timezone.utc).isoformat(),
                ":organisation": organisation,
                ":entity": entity,
            },
        )
        logger.info(f"Updated bookmark for {organisation} {entity}")
    except ClientError as e:
        logger.error(f"Failed to update bookmark: {e}")
        raise


@tracer.capture_method
def write_run_data(
    organisation: str, entity: str, run_id: str, run_data: dict, s3_files: list
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
        "organisation": organisation,
        "entity": entity,
        "run_id": run_id,
        "log_data": "run",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "retrieval": run_data.get("retrieval", 0),
        "size": total_size,
        "request_count": run_data.get("request_count", 0),
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
def write_request_data(organisation: str, entity: str, run_id: str, requests: list):
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
                "organisation": organisation,
                "entity": entity,
                "run_id": run_id,
                "log_data": "request",
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
def write_s3_data(organisation: str, entity: str, run_id: str, s3_files: list):
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
                "organisation": organisation,
                "entity": entity,
                "run_id": run_id,
                "log_data": "s3",
                "created_at": timestamp,
                "s3_key": file.get("s3_key"),
                "size": file.get("size", 0),
                "row_count": file.get("row_count", 0),
            }

            # Convert floats to Decimal
            item = json.loads(json.dumps(item), parse_float=Decimal)
            batch.put_item(Item=item)

    logger.info(f"Saved {len(s3_files)} S3 file records for run {run_id}")


@logger.inject_lambda_context
@tracer.capture_lambda_handler
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
        state_key = detail.get("state_key")

        if not run_id or not metadata_s3_key or not state_key:
            logger.warning("Missing run_id or metadata_s3_key or state_key in event")
            return

        # Validate state_key format
        organisation, entity = decode_state_key(state_key)

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
        run_metadata = full_metadata.get("run_metadata", {})
        requests = full_metadata.get("requests", [])
        s3_files = full_metadata.get("s3_files", [])

        # 1. Update Bookmark
        update_bookmark(organisation, entity, run_metadata, s3_files)

        # 2. Write Run Metadata (including Lambda metrics)
        write_run_data(organisation, entity, run_id, run_metadata, s3_files)

        # 3. Write Request Data
        write_request_data(organisation, entity, run_id, requests)

        # 4. Write S3 Data
        write_s3_data(organisation, entity, run_id, s3_files)

        # 5. Publish to AppSync for real-time frontend updates
        try:
            publish_crawler_completed(
                organisation=organisation,
                entity=entity,
                items_fetched=run_metadata.get("retrieval", 0),
                total_processed=run_metadata.get("total_processed", 0),
                last_processed_id=run_metadata.get("last_processed_id", 0),
            )
            logger.info("Published crawler completion event to AppSync")
        except Exception as e:
            logger.error(f"Failed to publish to AppSync: {e}")
            # Don't raise - AppSync is not critical

        logger.info(f"Successfully processed telemetry for run {run_id}")

    except Exception:
        logger.exception("Error processing telemetry event")
        raise  # Raise to trigger DLQ
