import json
import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import boto3
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit
from boto3.dynamodb.conditions import Key

# Environment variables
PROJECT_NAME = os.environ["PROJECT_NAME"]
TELEMETRY_TABLE_NAME = os.environ["TELEMETRY_TABLE_NAME"]
CLOUDWATCH_NAMESPACE = os.environ["CLOUDWATCH_NAMESPACE"]

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
    Returns (hour_str, start_iso, end_iso)
    """
    now = datetime.now(timezone.utc)
    # Go back 1 hour to process the full previous hour
    prev_hour = now - timedelta(hours=1)

    # Start of that hour
    start_time = prev_hour.replace(minute=0, second=0, microsecond=0)
    # End of that hour (start of current hour)
    end_time = now.replace(minute=0, second=0, microsecond=0)

    hour_str = start_time.strftime("%Y-%m-%d-%H")

    return hour_str, start_time.isoformat(), end_time.isoformat()


@tracer.capture_method
def query_requests_by_hour(crawler_type: str, start_time: str, end_time: str):
    """
    Query all requests for a crawler type within the time range.
    Uses GSI1: EntityTypeIndex (entity_type + created_at)
    """
    requests = []

    # We need to query specifically for requests
    # Since entity_type is "request", we can query directly
    # However, our GSI is on entity_type, so we need to filter by crawler_type
    # But wait, the schema says:
    # So we can query entity_type="request" and created_at between start and end
    # Then filter by crawler_type in memory (since we can't filter on GSI sort key efficiently if we want range)
    # Actually, we can use FilterExpression for crawler_type

    try:
        response = telemetry_table.query(
            IndexName="EntityTypeIndex",
            KeyConditionExpression=Key("entity_type").eq("request")
            & Key("created_at").between(start_time, end_time),
            FilterExpression=Key("crawler_type").eq(crawler_type),
        )

        requests.extend(response.get("Items", []))

        while "LastEvaluatedKey" in response:
            response = telemetry_table.query(
                IndexName="EntityTypeIndex",
                KeyConditionExpression=Key("entity_type").eq("request")
                & Key("created_at").between(start_time, end_time),
                FilterExpression=Key("crawler_type").eq(crawler_type),
                ExclusiveStartKey=response["LastEvaluatedKey"],
            )
            requests.extend(response.get("Items", []))

        return requests
    except Exception as e:
        logger.error(f"Failed to query requests: {e}")
        raise


@tracer.capture_method
def calculate_aggregations(requests: list):
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

    return {
        "count": count,
        "total_retrieval": total_retrieval,
        "avg_retrieval": avg_retrieval,
        "min_retrieval": min_retrieval,
        "max_retrieval": max_retrieval,
    }


@tracer.capture_method
def write_aggregation(crawler_type: str, metric_type: str, hour: str, stats: dict):
    """
    Write aggregated stats to DynamoDB.
    """
    pk = f"AGGREGATION#{crawler_type.upper()}#{metric_type.upper()}"
    sk = f"HOUR#{hour}"

    item = {
        "PK": pk,
        "SK": sk,
        "entity_type": "aggregation",
        "crawler_type": crawler_type,
        "metric_type": metric_type,
        "hour": hour,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "total": stats["total_retrieval"]
        if metric_type == "retrievals"
        else stats["count"],
        "average": stats["avg_retrieval"]
        if metric_type == "retrievals"
        else (
            stats["count"] / 1.0
        ),  # Avg requests per hour is just the count for that hour
        "min": stats["min_retrieval"] if metric_type == "retrievals" else 0,
        "max": stats["max_retrieval"] if metric_type == "retrievals" else 0,
        "count": stats["count"],
    }

    # Special handling for "requests" metric type
    # If metric_type is "requests", "total" is just the count of requests
    # "average" doesn't make much sense for "requests per hour" unless we aggregate by minute,
    # but here we are just storing the hourly total.
    # Let's align with the schema:
    # For "requests": total = count, average = count (or maybe avg per run if we had run data)
    # Let's stick to the simple interpretation:
    # requests: total = number of requests
    # retrievals: total = sum of items retrieved

    # Convert floats to Decimal
    item = json.loads(json.dumps(item), parse_float=Decimal)

    try:
        telemetry_table.put_item(Item=item)
        logger.info(f"Saved aggregation {pk} {sk}")
    except Exception as e:
        logger.error(f"Failed to save aggregation: {e}")
        raise


@tracer.capture_method
def publish_metrics(crawler_type: str, stats: dict):
    """
    Publish aggregated metrics to CloudWatch.
    """
    metrics.add_metric(
        name="HourlyRequests", unit=MetricUnit.Count, value=stats["count"]
    )
    metrics.add_metric(
        name="HourlyRetrievals", unit=MetricUnit.Count, value=stats["total_retrieval"]
    )
    metrics.add_metric(
        name="AvgRetrievalPerRequest",
        unit=MetricUnit.Count,
        value=stats["avg_retrieval"],
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

    hour_str, start_time, end_time = get_hour_boundary()
    logger.info(f"Processing hour: {hour_str} ({start_time} to {end_time})")

    crawler_types = ["repo", "user"]

    for crawler_type in crawler_types:
        try:
            # 1. Query Data
            requests = query_requests_by_hour(crawler_type, start_time, end_time)
            logger.info(f"Found {len(requests)} requests for {crawler_type}")

            if not requests:
                logger.info(f"No data for {crawler_type}, skipping")
                continue

            # 2. Calculate Stats
            stats = calculate_aggregations(requests)

            # 3. Write Aggregations
            # Metric: Retrievals (items fetched)
            write_aggregation(crawler_type, "retrievals", hour_str, stats)

            # Metric: Requests (API calls)
            # For requests, we just want the count
            req_stats = stats.copy()
            req_stats["total_retrieval"] = stats["count"]  # Total requests
            req_stats["avg_retrieval"] = 0  # Not applicable
            req_stats["min_retrieval"] = 0
            req_stats["max_retrieval"] = 0
            write_aggregation(crawler_type, "requests", hour_str, req_stats)

            # 4. Publish CloudWatch Metrics
            publish_metrics(crawler_type, stats)

        except Exception as e:
            logger.error(f"Error processing {crawler_type}: {e}")
            # Continue to next crawler type instead of failing completely

    logger.info("Aggregation complete")
