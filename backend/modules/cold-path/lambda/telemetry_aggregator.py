import json
import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import boto3
from aws_lambda_powertools import Logger, Tracer
from boto3.dynamodb.conditions import Key
from utils.crawler_utils import decode_state_key
from utils.sentry_config import init_sentry

# Initialize Sentry
init_sentry()

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
TELEMETRY_TABLE_NAME = os.environ["TELEMETRY_TABLE_NAME"]


# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-github-aggregator")
tracer = Tracer(service=f"{PROJECT_NAME}-github-aggregator")


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
def query_items_by_type(entity: str, log_data: str, start_time: str, end_time: str):
    """
    Query items (requests or runs) for a crawler type within the time range.
    Uses GSI1: EntityIndex (entity + created_at)
    """
    items = []

    try:
        response = telemetry_table.query(
            IndexName="EntityIndex",
            KeyConditionExpression=Key("entity").eq(entity)
            & Key("created_at").between(start_time, end_time),
            FilterExpression=Key("log_data").eq(log_data),
        )

        items.extend(response.get("Items", []))

        while "LastEvaluatedKey" in response:
            response = telemetry_table.query(
                IndexName="EntityIndex",
                KeyConditionExpression=Key("entity").eq(entity)
                & Key("created_at").between(start_time, end_time),
                FilterExpression=Key("log_data").eq(log_data),
                ExclusiveStartKey=response["LastEvaluatedKey"],
            )
            items.extend(response.get("Items", []))

        return items
    except Exception as e:
        logger.error(f"Failed to query {entity}: {e}")
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
    organisation: str,
    entity: str,
    metric_type: str,
    period_key: str,
    stats: dict,
    is_daily: bool = False,
):
    """
    Write aggregated stats to DynamoDB.
    period_key: "HOUR#..." or "DAY#..."
    """
    pk = f"AGG#{organisation.upper()}#{entity.upper()}#{metric_type.upper()}"
    sk = period_key

    item = {
        "PK": pk,
        "SK": sk,
        "organisation": organisation,
        "entity": entity,
        "log_data": "aggregation",
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
def perform_daily_rollup(organisation: str, entity: str, day_str: str):
    """
    Aggregate all hourly records for the day into a daily record.
    """
    logger.info(f"Performing daily rollup for {entity} on {day_str}")

    metric_types = ["retrievals", "requests", "runs"]

    for metric_type in metric_types:
        pk = f"AGG#{organisation.upper()}#{entity.upper()}#{metric_type.upper()}"

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
                    "min_retrieval": (
                        min(float(i["min"]) for i in hourly_items)
                        if hourly_items
                        else 0
                    ),
                    "max_retrieval": (
                        max(float(i["max"]) for i in hourly_items)
                        if hourly_items
                        else 0
                    ),
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
                organisation,
                entity,
                metric_type,
                f"DAY#{day_str}",
                daily_stats,
                is_daily=True,
            )

        except Exception as e:
            logger.error(f"Failed daily rollup for {metric_type}: {e}")


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def lambda_handler(event, _context):
    """
    Main Lambda handler
    Expects event to contain "state_key" (encoded)
    """
    state_key = event.get("state_key")

    if not state_key:
        logger.error("Missing state_key in event")
        raise ValueError("Missing state_key in event")

    # Decode state_key to get organisation and entity
    organisation, entity = decode_state_key(state_key)
    logger.info(f"Processing aggregation for {organisation}/{entity}")

    try:
        hour_str, start_time, end_time, is_end_of_day = get_hour_boundary()
        logger.info(f"Processing hour: {hour_str} ({start_time} to {end_time})")

        # 1. Process Requests
        requests = query_items_by_type(entity, "request", start_time, end_time)
        req_stats = None

        if requests:
            logger.info(f"Found {len(requests)} requests for {organisation}/{entity}")
            req_stats = calculate_request_stats(requests)

            # Write Retrieval Stats
            write_aggregation(
                organisation, entity, "retrievals", f"HOUR#{hour_str}", req_stats
            )

            # Write Request Stats (with errors)
            write_aggregation(
                organisation, entity, "requests", f"HOUR#{hour_str}", req_stats
            )
        else:
            logger.info(f"No requests for {organisation}/{entity}")

        # 2. Process Runs
        runs = query_items_by_type(entity, "run", start_time, end_time)
        run_stats = None

        if runs:
            logger.info(f"Found {len(runs)} runs for {organisation}/{entity}")
            run_stats = calculate_run_stats(runs)

            # Write Run Stats
            write_aggregation(
                organisation, entity, "runs", f"HOUR#{hour_str}", run_stats
            )
        else:
            logger.info(f"No runs for {organisation}/{entity}")

        # 3 Daily Rollup (if end of day)
        if is_end_of_day:
            day_str = hour_str[:10]  # YYYY-MM-DD
            perform_daily_rollup(organisation, entity, day_str)

    except Exception as e:
        logger.error(f"Error processing {state_key}: {e}")
        # Continue to next crawler instead of failing completely

    logger.info("Aggregation complete")
