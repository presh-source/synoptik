import base64
import os
from datetime import datetime, timezone

import boto3
from aws_lambda_powertools import Logger, Tracer
from botocore.exceptions import ClientError

# Environment variables
PROJECT_NAME = os.environ.get("PROJECT_NAME")
CRAWL_STATE_TABLE_NAME = os.environ.get("CRAWL_STATE_TABLE_NAME")

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")
if CRAWL_STATE_TABLE_NAME:
    crawl_state_table = dynamodb.Table(CRAWL_STATE_TABLE_NAME)
else:
    logger.warning("CRAWL_STATE_TABLE_NAME environment variable not set")
    crawl_state_table = None

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-crawler-utils")
tracer = Tracer(service=f"{PROJECT_NAME}-crawler-utils")

@tracer.capture_method
def decode_state_key(state_key: str) -> tuple[str, str]:
    """
    Decode state_key to extract organisation and entity.
    Format: STATE#{organisation}#{entity}
    """
    try:
        decoded_key = base64.b64decode(state_key).decode("utf-8")
        parts = decoded_key.split("#")
        if len(parts) != 3:
            raise ValueError("Invalid state_key format")
        return parts[1], parts[2]
    except Exception as e:
        logger.warning(f"Failed to decode state_key: {e}")
        raise ValueError("Invalid state_key format") from e


@tracer.capture_method
def get_crawler_config(state_key: str) -> dict:
    """
    Fetch crawler configuration from DynamoDB using the state_key.
    Returns a dictionary with configuration and current state.
    """
    
    # Validate state_key format
    decode_state_key(state_key)
    
    if not crawl_state_table:
        raise ValueError("CRAWL_STATE_TABLE_NAME not configured")

    try:
        response = crawl_state_table.get_item(
            Key={"state_key": state_key}, ConsistentRead=True
        )

        if "Item" not in response:
            raise ValueError(f"No configuration found for state_key: {state_key}")

        item = response["Item"]
        config = {
            "state_key": state_key,
            "organisation": item.get("organisation"),
            "entity": item.get("entity"),
            "s3_prefix": item.get("s3_prefix"),
            "last_processed_id": int(item.get("last_processed_id")),
            "total_processed": int(item.get("total_processed")),
            "endpoint": item.get("endpoint"),
            "requests_per_execution": int(item.get("requests_per_execution")),
            "sleep_interval": float(item.get("sleep_interval")),
        }
        
        logger.info(f"Loaded configuration for {config['organisation']}/{config['entity']}", extra=config)
        return config

    except ClientError as e:
        logger.error("Failed to fetch configuration from DynamoDB", extra={"error": str(e)})
        raise
