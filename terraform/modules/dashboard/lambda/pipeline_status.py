"""
Pipeline Status Lambda
Queries DynamoDB, Kinesis, and SQS to provide pipeline status information
"""
import json
import os
from datetime import datetime, timedelta
from typing import Dict, Any
import boto3
from botocore.exceptions import ClientError

# AWS Lambda Powertools
from aws_lambda_powertools import Logger, Tracer, Metrics

# Environment variables
PROJECT_NAME = os.environ['PROJECT_NAME']
DYNAMODB_TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
KINESIS_STREAM_NAME = os.environ['KINESIS_STREAM_NAME']
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']
ENVIRONMENT = os.environ['ENVIRONMENT']

# Initialize Powertools
logger = Logger(service=f"{PROJECT_NAME}-pipeline-status")
tracer = Tracer(service=f"{PROJECT_NAME}-pipeline-status")
metrics = Metrics(namespace=f"{PROJECT_NAME.title()}/Dashboard", service="pipeline-status")

# Initialize AWS clients
dynamodb = boto3.client('dynamodb')
kinesis = boto3.client('kinesis')
sqs = boto3.client('sqs')
cloudwatch = boto3.client('cloudwatch')

# Constants
TOTAL_GITHUB_REPOS = 500_000_000  # 500M repositories target


def get_cold_path_status() -> Dict[str, Any]:
    """
    Query DynamoDB for Cold Path bookmark and calculate ingestion metrics
    """
    try:
        response = dynamodb.get_item(
            TableName=DYNAMODB_TABLE_NAME,
            Key={'state_key': {'S': 'bookmark'}},
            ConsistentRead=True
        )
        
        if 'Item' not in response:
            logger.warning("No bookmark found in DynamoDB")
            return {
                "status": "not_started",
                "last_processed_id": 0,
                "total_processed": 0,
                "ingestion_rate": 0,
                "progress_percentage": 0.0,
                "updated_at": None
            }
        
        item = response['Item']
        last_processed_id = int(item.get('last_processed_id', {}).get('N', 0))
        total_processed = int(item.get('total_processed', {}).get('N', 0))
        updated_at = item.get('updated_at', {}).get('S', '')
        
        # Calculate ingestion rate (repos per hour)
        ingestion_rate = calculate_ingestion_rate(updated_at, total_processed)
        
        # Calculate progress percentage
        progress_percentage = (last_processed_id / TOTAL_GITHUB_REPOS) * 100
        
        # Determine status
        status = "running" if ingestion_rate > 0 else "stalled"
        
        return {
            "status": status,
            "last_processed_id": last_processed_id,
            "total_processed": total_processed,
            "ingestion_rate": ingestion_rate,
            "progress_percentage": round(progress_percentage, 4),
            "updated_at": updated_at,
            "estimated_completion_hours": calculate_estimated_completion(
                last_processed_id, ingestion_rate
            )
        }
        
    except ClientError as e:
        logger.error(f"Error querying DynamoDB: {e}")
        return {
            "status": "error",
            "error": str(e),
            "last_processed_id": 0,
            "total_processed": 0,
            "ingestion_rate": 0,
            "progress_percentage": 0.0
        }


def calculate_ingestion_rate(updated_at: str, total_processed: int) -> float:
    """
    Calculate ingestion rate in repositories per hour
    Uses CloudWatch metrics for more accurate calculation
    """
    try:
        # Query CloudWatch for RepositoriesProcessed metric over last hour
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=1)
        
        response = cloudwatch.get_metric_statistics(
            Namespace=f'{PROJECT_NAME.title()}/ColdPath',
            MetricName='RepositoriesProcessed',
            Dimensions=[],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,  # 1 hour
            Statistics=['Sum']
        )
        
        if response['Datapoints']:
            # Get the most recent datapoint
            datapoints = sorted(response['Datapoints'], key=lambda x: x['Timestamp'], reverse=True)
            return datapoints[0]['Sum']
        
        # Fallback: calculate based on expected rate (4,500 req/hr * ~100 repos/req)
        return 0.0
        
    except Exception as e:
        logger.warning(f"Could not calculate ingestion rate from CloudWatch: {e}")
        return 0.0


def calculate_estimated_completion(last_processed_id: int, ingestion_rate: float) -> float:
    """
    Calculate estimated hours until completion
    """
    if ingestion_rate <= 0:
        return -1  # Unknown
    
    remaining_repos = TOTAL_GITHUB_REPOS - last_processed_id
    hours_remaining = remaining_repos / ingestion_rate
    
    return round(hours_remaining, 2)


def get_hot_path_status() -> Dict[str, Any]:
    """
    Query Kinesis metrics for Hot Path status
    """
    try:
        # Get stream description
        response = kinesis.describe_stream(StreamName=KINESIS_STREAM_NAME)
        stream_status = response['StreamDescription']['StreamStatus']
        
        # Query CloudWatch for event processing rate
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=5)
        
        # Get incoming records metric
        incoming_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/Kinesis',
            MetricName='IncomingRecords',
            Dimensions=[
                {'Name': 'StreamName', 'Value': KINESIS_STREAM_NAME}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,  # 5 minutes
            Statistics=['Sum']
        )
        
        events_per_minute = 0
        if incoming_response['Datapoints']:
            datapoints = sorted(incoming_response['Datapoints'], key=lambda x: x['Timestamp'], reverse=True)
            total_events = datapoints[0]['Sum']
            events_per_minute = total_events / 5  # Average over 5 minutes
        
        # Get iterator age (lag) metric
        lag_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/Kinesis',
            MetricName='GetRecords.IteratorAgeMilliseconds',
            Dimensions=[
                {'Name': 'StreamName', 'Value': KINESIS_STREAM_NAME}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Maximum']
        )
        
        kinesis_lag_ms = 0
        if lag_response['Datapoints']:
            datapoints = sorted(lag_response['Datapoints'], key=lambda x: x['Timestamp'], reverse=True)
            kinesis_lag_ms = datapoints[0]['Maximum']
        
        return {
            "status": stream_status.lower(),
            "events_per_minute": round(events_per_minute, 2),
            "kinesis_lag_ms": round(kinesis_lag_ms, 2),
            "stream_status": stream_status
        }
        
    except ClientError as e:
        logger.error(f"Error querying Kinesis: {e}")
        return {
            "status": "error",
            "error": str(e),
            "events_per_minute": 0,
            "kinesis_lag_ms": 0
        }


def get_scrubber_path_status() -> Dict[str, Any]:
    """
    Query SQS queue depth for Scrubber Path status
    """
    try:
        response = sqs.get_queue_attributes(
            QueueUrl=SQS_QUEUE_URL,
            AttributeNames=[
                'ApproximateNumberOfMessages',
                'ApproximateNumberOfMessagesNotVisible',
                'ApproximateNumberOfMessagesDelayed'
            ]
        )
        
        attributes = response['Attributes']
        queue_depth = int(attributes.get('ApproximateNumberOfMessages', 0))
        in_flight = int(attributes.get('ApproximateNumberOfMessagesNotVisible', 0))
        delayed = int(attributes.get('ApproximateNumberOfMessagesDelayed', 0))
        
        # Query CloudWatch for validation rate
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=1)
        
        validation_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Invocations',
            Dimensions=[
                {'Name': 'FunctionName', 'Value': f'{ENVIRONMENT}-{PROJECT_NAME}-pinger'}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,  # 1 hour
            Statistics=['Sum']
        )
        
        validation_rate = 0
        if validation_response['Datapoints']:
            datapoints = sorted(validation_response['Datapoints'], key=lambda x: x['Timestamp'], reverse=True)
            validation_rate = datapoints[0]['Sum']
        
        # Determine status
        if queue_depth > 0 or in_flight > 0:
            status = "running"
        elif queue_depth == 0 and in_flight == 0:
            status = "idle"
        else:
            status = "unknown"
        
        return {
            "status": status,
            "queue_depth": queue_depth,
            "in_flight": in_flight,
            "delayed": delayed,
            "validation_rate": validation_rate
        }
        
    except ClientError as e:
        logger.error(f"Error querying SQS: {e}")
        return {
            "status": "error",
            "error": str(e),
            "queue_depth": 0,
            "validation_rate": 0
        }


@logger.inject_lambda_context(log_event=True)
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event, context):
    """
    API Gateway handler for /api/pipeline-status endpoint
    Returns status of Cold Path, Hot Path, and Scrubber Path pipelines
    """
    try:
        # Query all pipeline statuses
        cold_path = get_cold_path_status()
        hot_path = get_hot_path_status()
        scrubber_path = get_scrubber_path_status()
        
        response = {
            "cold_path": cold_path,
            "hot_path": hot_path,
            "scrubber_path": scrubber_path,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "GET,OPTIONS"
            },
            "body": json.dumps(response)
        }
        
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "GET,OPTIONS"
            },
            "body": json.dumps({
                "error": "Internal server error",
                "message": str(e)
            })
        }
