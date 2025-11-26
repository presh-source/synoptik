import logging
import os

import boto3

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("TELEMETRY_TABLE_NAME")
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    return event, context
