import os
from datetime import datetime, timedelta, timezone

import boto3
from aws_lambda_powertools import Logger, Tracer
from boto3.dynamodb.conditions import Key

logger = Logger(service="crawler-stats-resolver")
tracer = Tracer(service="crawler-stats-resolver")

dynamodb = boto3.resource("dynamodb")
TELEMETRY_TABLE_NAME = os.environ["TELEMETRY_TABLE_NAME"]
telemetry_table = dynamodb.Table(TELEMETRY_TABLE_NAME)


@tracer.capture_method
def get_aggregated_stats(
    crawler_type: str, start_time: datetime, end_time: datetime
) -> dict:

    # Query aggregations for "retrieval" metric
    pk = f"AGG#{crawler_type}#retrieval"

    start_hour = start_time.strftime("%Y-%m-%dT%H")
    end_hour = end_time.strftime("%Y-%m-%dT%H")

    response = telemetry_table.query(
        KeyConditionExpression=Key("PK").eq(pk)
        & Key("SK").between(start_hour, end_hour)
    )

    items = response.get("Items", [])

    total_processed = sum(int(item["total"]) for item in items)
    total_runs = sum(int(item["count"]) for item in items)

    # Calculate average items per hour
    hours_diff = (end_time - start_time).total_seconds() / 3600
    avg_items_per_hour = total_processed / hours_diff if hours_diff > 0 else 0

    # Get total size from "size" metric
    pk_size = f"AGG#{crawler_type}#size"
    response_size = telemetry_table.query(
        KeyConditionExpression=Key("PK").eq(pk_size)
        & Key("SK").between(start_hour, end_hour)
    )
    items_size = response_size.get("Items", [])
    total_size = sum(int(item["total"]) for item in items_size)

    # Get last run time
    # Query EntityTypeIndex for latest run
    # Limit 1, ScanIndexForward=False

    last_run = None
    try:
        run_response = telemetry_table.query(
            IndexName="EntityTypeIndex",
            KeyConditionExpression=Key("entity_type").eq(f"RUN#{crawler_type}"),
            Limit=1,
            ScanIndexForward=False,
        )
        if run_response.get("Items"):
            last_run = run_response["Items"][0]["created_at"]
    except Exception as e:
        logger.error(f"Failed to get last run: {e}")

    return {
        "total_runs": total_runs,
        "total_processed": total_processed,
        "total_size": total_size,
        "avg_items_per_hour": avg_items_per_hour,
        "last_run": last_run,
    }


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event, context):
    time_range = event.get("arguments", {}).get("timeRange", "24h")

    now = datetime.now(timezone.utc)

    if time_range == "24h":
        start_time = now - timedelta(hours=24)
    elif time_range == "7d":
        start_time = now - timedelta(days=7)
    elif time_range == "30d":
        start_time = now - timedelta(days=30)
    else:
        start_time = now - timedelta(hours=24)

    repo_stats = get_aggregated_stats("repo", start_time, now)
    user_stats = get_aggregated_stats("user", start_time, now)

    return {"repo": repo_stats, "user": user_stats}
