import json
import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import boto3
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit
from boto3.dynamodb.conditions import Key
from utils.sentry_config import init_sentry

# Initialize Sentry
init_sentry()

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
TELEMETRY_TABLE_NAME = os.environ["TELEMETRY_TABLE_NAME"]


# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-github-aggregator")
tracer = Tracer(service=f"{PROJECT_NAME}-github-aggregator")
metrics = Metrics(namespace=f"{PROJECT_NAME.title()}/ColdPath", service="aggregator")


# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")
telemetry_table = dynamodb.Table(TELEMETRY_TABLE_NAME)


def get_hour_boundary():
    """
    Get the start and end timestamps for the previous hour.
    Returns (hour_str, start_iso, end_iso, is_end_of_day)
    """
    now = datetime.now(timezone.utc)
    # Go back 1 hour to process the full previous hour
    prev_hour = now - timedelta(hours=1)

    # Start of that hour
    start_time = prev_hour.replace(minute=0, second=0, microsecond=0)
    # End of that hour (start of current hour)
    end_time = now.replace(minute=0, second=0, microsecond=0)

    hour_str = start_time.strftime("%Y-%m-%d-%H")

    # Check if this was the last hour of the day (23:00)
    is_end_of_day = start_time.hour == 23

    return hour_str, start_time.isoformat(), end_time.isoformat(), is_end_of_day


@tracer.capture_method
def query_items_by_type(
    crawler_type: str, entity_type: str, start_time: str, end_time: str
):
    """
    Query items (requests or runs) for a crawler type within the time range.
    Uses GSI1: EntityTypeIndex (entity_type + created_at)
    """
    items = []

    try:
        response = telemetry_table.query(
            IndexName="EntityTypeIndex",
            KeyConditionExpression=Key("entity_type").eq(entity_type)
            & Key("created_at").between(start_time, end_time),
            FilterExpression=Key("crawler_type").eq(crawler_type),
        )

        items.extend(response.get("Items", []))

        while "LastEvaluatedKey" in response:
            response = telemetry_table.query(
                IndexName="EntityTypeIndex",
                KeyConditionExpression=Key("entity_type").eq(entity_type)
                & Key("created_at").between(start_time, end_time),
                FilterExpression=Key("crawler_type").eq(crawler_type),
                ExclusiveStartKey=response["LastEvaluatedKey"],
            )
            items.extend(response.get("Items", []))

        return items
    except Exception as e:
        logger.error(f"Failed to query {entity_type}: {e}")
        raise


@tracer.capture_method
def calculate_request_stats(requests: list):
    """
    Calculate metrics from a list of requests.
    """
    if not requests:
        return None

    count = len(requests)

    # Retrievals
    retrievals = [float(r.get("retrieval", 0)) for r in requests]
    total_retrieval = sum(retrievals)
    avg_retrieval = total_retrieval / count if count > 0 else 0
    min_retrieval = min(retrievals) if retrievals else 0
    max_retrieval = max(retrievals) if retrievals else 0

    # Errors
    errors = [r for r in requests if float(r.get("status_code", 200)) >= 400]
    error_count = len(errors)
    error_rate = (error_count / count) * 100 if count > 0 else 0

    return {
        "count": count,
        "total_retrieval": total_retrieval,
        "avg_retrieval": avg_retrieval,
        "min_retrieval": min_retrieval,
        "max_retrieval": max_retrieval,
        "error_count": error_count,
        "error_rate": error_rate,
    }


@tracer.capture_method
def calculate_run_stats(runs: list):
    """
    Calculate metrics from a list of runs.
    """
    if not runs:
        return None

    count = len(runs)

    # Durations (if available)
    durations = [float(r.get("duration_ms", 0)) for r in runs]
    total_duration = sum(durations)
    avg_duration = total_duration / count if count > 0 else 0

    # Sizes
    sizes = [float(r.get("size", 0)) for r in runs]
    total_size = sum(sizes)

    # Items
    items = [float(r.get("retrieval", 0)) for r in runs]
    total_items = sum(items)

    return {
        "count": count,
        "total_duration": total_duration,
        "avg_duration": avg_duration,
        "total_size": total_size,
        "total_items": total_items,
    }


@tracer.capture_method
def write_aggregation(
    crawler_type: str,
    metric_type: str,
    period_key: str,
    stats: dict,
    is_daily: bool = False,
):
    """
    Write aggregated stats to DynamoDB.
    period_key: "HOUR#..." or "DAY#..."
    """
    pk = f"AGG#{crawler_type.upper()}#{metric_type.upper()}"
    sk = period_key

    item = {
        "PK": pk,
        "SK": sk,
        "entity_type": "aggregation",
        "crawler_type": crawler_type,
        "metric_type": metric_type,
        "period": "day" if is_daily else "hour",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "count": stats["count"],
    }

    # Add metric-specific fields
    if metric_type == "retrievals":
        item.update(
            {
                "total": stats["total_retrieval"],
                "average": stats["avg_retrieval"],
                "min": stats["min_retrieval"],
                "max": stats["max_retrieval"],
            }
        )
    elif metric_type == "requests":
        item.update(
            {
                "total": stats["count"],
                "error_count": stats["error_count"],
                "error_rate": stats["error_rate"],
            }
        )
    elif metric_type == "runs":
        item.update(
            {
                "total_duration": stats["total_duration"],
                "avg_duration": stats["avg_duration"],
                "total_size": stats["total_size"],
                "total_items": stats["total_items"],
            }
        )

    # Convert floats to Decimal
    item = json.loads(json.dumps(item), parse_float=Decimal)

    try:
        telemetry_table.put_item(Item=item)
        logger.info(f"Saved aggregation {pk} {sk}")
    except Exception as e:
        logger.error(f"Failed to save aggregation: {e}")
        raise


@tracer.capture_method
def perform_daily_rollup(crawler_type: str, day_str: str):
    """
    Aggregate all hourly records for the day into a daily record.
    """
    logger.info(f"Performing daily rollup for {crawler_type} on {day_str}")

    metric_types = ["retrievals", "requests", "runs"]

    for metric_type in metric_types:
        pk = f"AGG#{crawler_type.upper()}#{metric_type.upper()}"

        try:
            # Query all hours for this day
            response = telemetry_table.query(
                KeyConditionExpression=Key("PK").eq(pk)
                & Key("SK").begins_with(f"HOUR#{day_str}")
            )

            hourly_items = response.get("Items", [])
            if not hourly_items:
                logger.info(f"No hourly data for {metric_type} on {day_str}")
                continue

            # Aggregate stats
            daily_stats = {"count": 0}

            if metric_type == "retrievals":
                total_retrieval = sum(float(i["total"]) for i in hourly_items)
                count = sum(int(i["count"]) for i in hourly_items)
                daily_stats = {
                    "count": count,
                    "total_retrieval": total_retrieval,
                    "avg_retrieval": total_retrieval / count if count > 0 else 0,
                    "min_retrieval": min(float(i["min"]) for i in hourly_items)
                    if hourly_items
                    else 0,
                    "max_retrieval": max(float(i["max"]) for i in hourly_items)
                    if hourly_items
                    else 0,
                }
            elif metric_type == "requests":
                count = sum(int(i["count"]) for i in hourly_items)
                error_count = sum(int(i.get("error_count", 0)) for i in hourly_items)
                daily_stats = {
                    "count": count,
                    "error_count": error_count,
                    "error_rate": (error_count / count) * 100 if count > 0 else 0,
                }
            elif metric_type == "runs":
                count = sum(int(i["count"]) for i in hourly_items)
                total_duration = sum(float(i["total_duration"]) for i in hourly_items)
                daily_stats = {
                    "count": count,
                    "total_duration": total_duration,
                    "avg_duration": total_duration / count if count > 0 else 0,
                    "total_size": sum(float(i["total_size"]) for i in hourly_items),
                    "total_items": sum(float(i["total_items"]) for i in hourly_items),
                }

            # Write daily aggregation
            write_aggregation(
                crawler_type, metric_type, f"DAY#{day_str}", daily_stats, is_daily=True
            )

        except Exception as e:
            logger.error(f"Failed daily rollup for {metric_type}: {e}")


@tracer.capture_method
def publish_metrics(crawler_type: str, req_stats: dict, run_stats: dict):
    """
    Publish aggregated metrics to CloudWatch.
    """
    if req_stats:
        metrics.add_metric(
            name="HourlyRequests", unit=MetricUnit.Count, value=req_stats["count"]
        )
        metrics.add_metric(
            name="HourlyRetrievals",
            unit=MetricUnit.Count,
            value=req_stats["total_retrieval"],
        )
        metrics.add_metric(
            name="AvgRetrievalPerRequest",
            unit=MetricUnit.Count,
            value=req_stats["avg_retrieval"],
        )
        metrics.add_metric(
            name="ErrorRate",
            unit=MetricUnit.Percent,
            value=req_stats["error_rate"],
        )

    if run_stats:
        metrics.add_metric(
            name="HourlyRuns", unit=MetricUnit.Count, value=run_stats["count"]
        )
        metrics.add_metric(
            name="AvgRunDuration",
            unit=MetricUnit.Milliseconds,
            value=run_stats["avg_duration"],
        )
        metrics.add_metric(
            name="HourlyDataSize", unit=MetricUnit.Bytes, value=run_stats["total_size"]
        )

    metrics.add_dimension(name="CrawlerType", value=crawler_type)


@logger.inject_lambda_context
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(_event, _context):
    """
    Main handler for hourly aggregation.
    """
    logger.info("Starting hourly aggregation")

    hour_str, start_time, end_time, is_end_of_day = get_hour_boundary()
    logger.info(f"Processing hour: {hour_str} ({start_time} to {end_time})")

    crawler_types = ["repo", "user"]

    for crawler_type in crawler_types:
        try:
            # 1. Process Requests
            requests = query_items_by_type(
                crawler_type, "request", start_time, end_time
            )
            req_stats = None

            if requests:
                logger.info(f"Found {len(requests)} requests for {crawler_type}")
                req_stats = calculate_request_stats(requests)

                # Write Retrieval Stats
                write_aggregation(
                    crawler_type, "retrievals", f"HOUR#{hour_str}", req_stats
                )

                # Write Request Stats (with errors)
                write_aggregation(
                    crawler_type, "requests", f"HOUR#{hour_str}", req_stats
                )
            else:
                logger.info(f"No requests for {crawler_type}")

            # 2. Process Runs
            runs = query_items_by_type(crawler_type, "run", start_time, end_time)
            run_stats = None

            if runs:
                logger.info(f"Found {len(runs)} runs for {crawler_type}")
                run_stats = calculate_run_stats(runs)

                # Write Run Stats
                write_aggregation(crawler_type, "runs", f"HOUR#{hour_str}", run_stats)
            else:
                logger.info(f"No runs for {crawler_type}")

            # 3. Publish CloudWatch Metrics
            if req_stats or run_stats:
                publish_metrics(crawler_type, req_stats, run_stats)

            # 4. Daily Rollup (if end of day)
            if is_end_of_day:
                day_str = hour_str[:10]  # YYYY-MM-DD
                perform_daily_rollup(crawler_type, day_str)

        except Exception as e:
            logger.error(f"Error processing {crawler_type}: {e}")
            # Continue to next crawler type instead of failing completely

    logger.info("Aggregation complete")
