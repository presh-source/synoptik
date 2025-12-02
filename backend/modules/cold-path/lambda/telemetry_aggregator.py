import json
import os
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import boto3
from aws_lambda_powertools import Logger, Tracer
from boto3.dynamodb.conditions import Key
from utils.crawler_utils import get_crawler_config
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
logs_client = boto3.client("logs")


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
def query_cloudwatch_logs(log_group_name: str, start_time: str, end_time: str):
    """
    Query CloudWatch Logs for Lambda REPORT lines within the time range.
    Returns parsed metrics from REPORT lines.
    """

    # Convert ISO timestamps to milliseconds since epoch
    start_ms = int(datetime.fromisoformat(start_time).timestamp() * 1000)
    end_ms = int(datetime.fromisoformat(end_time).timestamp() * 1000)

    filter_pattern = (
        "[report_type=REPORT, request_id_label=RequestId:, request_id, ...]"
    )

    try:
        results = []
        response = logs_client.filter_log_events(
            logGroupName=log_group_name,
            startTime=start_ms,
            endTime=end_ms,
            filterPattern=filter_pattern,
        )

        for event in response.get("events", []):
            message = event.get("message", "")
            parsed = parse_report_line(message)
            if parsed:
                results.append(parsed)

        # Handle pagination
        while "nextToken" in response:
            response = logs_client.filter_log_events(
                logGroupName=log_group_name,
                startTime=start_ms,
                endTime=end_ms,
                filterPattern=filter_pattern,
                nextToken=response["nextToken"],
            )
            for event in response.get("events", []):
                message = event.get("message", "")
                parsed = parse_report_line(message)
                if parsed:
                    results.append(parsed)

        logger.info(f"Found {len(results)} REPORT lines from CloudWatch Logs")
        return results

    except Exception as e:
        logger.error(f"Failed to query CloudWatch Logs: {e}")
        return []


def parse_report_line(message: str):
    """
    Parse a Lambda REPORT line to extract metrics.
    Example:
    REPORT RequestId: 078976cf-2340-498e-8dd9-ef1797447d8f	Duration: 3203.88 ms	Billed Duration: 6852 ms	Memory Size: 256 MB	Max Memory Used: 232 MB	Init Duration: 3647.56 ms
    """

    if not message.startswith("REPORT"):
        return None

    try:
        # Extract RequestId
        request_id_match = re.search(r"RequestId: ([a-f0-9-]+)", message)
        request_id = request_id_match.group(1) if request_id_match else None

        # Extract Duration (ms)
        duration_match = re.search(r"Duration: ([0-9.]+) ms", message)
        duration_ms = float(duration_match.group(1)) if duration_match else None

        # Extract Billed Duration (ms)
        billed_match = re.search(r"Billed Duration: ([0-9.]+) ms", message)
        billed_duration_ms = float(billed_match.group(1)) if billed_match else None

        # Extract Memory Size (MB)
        memory_size_match = re.search(r"Memory Size: ([0-9]+) MB", message)
        memory_size_mb = int(memory_size_match.group(1)) if memory_size_match else None

        # Extract Max Memory Used (MB)
        max_memory_match = re.search(r"Max Memory Used: ([0-9]+) MB", message)
        max_memory_used_mb = (
            int(max_memory_match.group(1)) if max_memory_match else None
        )

        # Extract Init Duration (ms) - may not always be present
        init_duration_match = re.search(r"Init Duration: ([0-9.]+) ms", message)
        init_duration_ms = (
            float(init_duration_match.group(1)) if init_duration_match else None
        )

        return {
            "request_id": request_id,
            "duration_ms": duration_ms,
            "billed_duration_ms": billed_duration_ms,
            "memory_size_mb": memory_size_mb,
            "max_memory_used_mb": max_memory_used_mb,
            "init_duration_ms": init_duration_ms,
        }
    except Exception as e:
        logger.warning(f"Failed to parse REPORT line: {message}. Error: {e}")
        return None


@tracer.capture_method
def calculate_run_stats(runs: list, cloudwatch_metrics: list = None):
    """
    Calculate metrics from a list of runs.
    Optionally include CloudWatch metrics from REPORT lines.
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

    stats = {
        "count": count,
        "total_duration": total_duration,
        "avg_duration": avg_duration,
        "total_size": total_size,
        "total_items": total_items,
    }

    # Add CloudWatch metrics if available
    if cloudwatch_metrics:
        cw_count = len(cloudwatch_metrics)

        # Lambda execution duration
        lambda_durations = [
            m["duration_ms"] for m in cloudwatch_metrics if m.get("duration_ms")
        ]
        if lambda_durations:
            stats["lambda_total_duration"] = sum(lambda_durations)
            stats["lambda_avg_duration"] = sum(lambda_durations) / len(lambda_durations)
            stats["lambda_min_duration"] = min(lambda_durations)
            stats["lambda_max_duration"] = max(lambda_durations)

        # Billed duration
        billed_durations = [
            m["billed_duration_ms"]
            for m in cloudwatch_metrics
            if m.get("billed_duration_ms")
        ]
        if billed_durations:
            stats["lambda_total_billed_duration"] = sum(billed_durations)
            stats["lambda_avg_billed_duration"] = sum(billed_durations) / len(
                billed_durations
            )

        # Memory usage
        max_memory_used = [
            m["max_memory_used_mb"]
            for m in cloudwatch_metrics
            if m.get("max_memory_used_mb")
        ]
        if max_memory_used:
            stats["lambda_avg_memory_used"] = sum(max_memory_used) / len(
                max_memory_used
            )
            stats["lambda_max_memory_used"] = max(max_memory_used)
            stats["lambda_min_memory_used"] = min(max_memory_used)

        # Memory size (should be constant)
        memory_sizes = [
            m["memory_size_mb"] for m in cloudwatch_metrics if m.get("memory_size_mb")
        ]
        if memory_sizes:
            stats["lambda_memory_size"] = memory_sizes[0]  # Should be the same for all

        # Init duration (cold starts)
        init_durations = [
            m["init_duration_ms"]
            for m in cloudwatch_metrics
            if m.get("init_duration_ms")
        ]
        if init_durations:
            stats["lambda_cold_starts"] = len(init_durations)
            stats["lambda_cold_start_rate"] = (len(init_durations) / cw_count) * 100
            stats["lambda_avg_init_duration"] = sum(init_durations) / len(
                init_durations
            )
            stats["lambda_max_init_duration"] = max(init_durations)
        else:
            stats["lambda_cold_starts"] = 0
            stats["lambda_cold_start_rate"] = 0

    return stats


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

        # Add optional CloudWatch metrics
        optional_fields = [
            "lambda_total_duration",
            "lambda_avg_duration",
            "lambda_min_duration",
            "lambda_max_duration",
            "lambda_total_billed_duration",
            "lambda_avg_billed_duration",
            "lambda_avg_memory_used",
            "lambda_max_memory_used",
            "lambda_min_memory_used",
            "lambda_memory_size",
            "lambda_cold_starts",
            "lambda_cold_start_rate",
            "lambda_avg_init_duration",
            "lambda_max_init_duration",
        ]
        for field in optional_fields:
            if field in stats:
                item[field] = stats[field]

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

    config = get_crawler_config(state_key)

    organisation = config["organisation"]
    entity = config["entity"]
    log_group_name = config.get("log_group_name")

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

            # Query CloudWatch Logs for Lambda execution metrics
            cloudwatch_metrics = []
            if log_group_name:
                try:
                    logger.info(f"Querying CloudWatch Logs: {log_group_name}")
                    cloudwatch_metrics = query_cloudwatch_logs(
                        log_group_name, start_time, end_time
                    )
                except Exception as e:
                    logger.warning(
                        f"Failed to query CloudWatch Logs: {e}. Continuing without CloudWatch metrics."
                    )
            else:
                logger.info("No log_group_name configured, skipping CloudWatch metrics")

            run_stats = calculate_run_stats(runs, cloudwatch_metrics)

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
