"""
CloudWatch Metrics Lambda
Fetches CloudWatch metrics for all pipelines
"""
import json
import os
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cloudwatch = boto3.client('cloudwatch')
lambda_client = boto3.client('lambda')

# Environment variables
PROJECT_NAME = os.environ.get('PROJECT_NAME', '')
ENVIRONMENT = os.environ.get('ENVIRONMENT', '')

# Lambda function names by pipeline
LAMBDA_FUNCTIONS = {
    'cold_path': f'{ENVIRONMENT}-{PROJECT_NAME}-crawler',
    'hot_path': [
        f'{ENVIRONMENT}-{PROJECT_NAME}-events-poller',
        f'{ENVIRONMENT}-{PROJECT_NAME}-graph-updater'
    ],
    'scrubber_path': f'{ENVIRONMENT}-{PROJECT_NAME}-pinger'
}


def get_metric_statistics(namespace: str, metric_name: str, dimensions: List[Dict[str, str]],
                          period: int = 3600, statistic: str = 'Average') -> Optional[float]:
    """
    Helper function to get CloudWatch metric statistics
    """
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=1)
        
        response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=dimensions,
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=[statistic]
        )
        
        if response['Datapoints']:
            datapoints = sorted(response['Datapoints'], key=lambda x: x['Timestamp'], reverse=True)
            return datapoints[0][statistic]
        
        return 0.0
        
    except ClientError as e:
        logger.error(f"Error getting metric {metric_name}: {e}")
        return None


def calculate_error_rate(function_name: str) -> float:
    """
    Calculate error rate for a Lambda function (errors / invocations)
    """
    try:
        dimensions = [{'Name': 'FunctionName', 'Value': function_name}]
        
        # Get errors
        errors = get_metric_statistics(
            'AWS/Lambda',
            'Errors',
            dimensions,
            statistic='Sum'
        ) or 0.0
        
        # Get invocations
        invocations = get_metric_statistics(
            'AWS/Lambda',
            'Invocations',
            dimensions,
            statistic='Sum'
        ) or 0.0
        
        if invocations > 0:
            return (errors / invocations) * 100
        
        return 0.0
        
    except Exception as e:
        logger.error(f"Error calculating error rate for {function_name}: {e}")
        return 0.0


def get_lambda_metrics(function_name: str) -> Dict[str, Any]:
    """
    Get comprehensive metrics for a Lambda function
    """
    try:
        dimensions = [{'Name': 'FunctionName', 'Value': function_name}]
        
        # Get invocations (for rate calculation)
        invocations = get_metric_statistics(
            'AWS/Lambda',
            'Invocations',
            dimensions,
            statistic='Sum'
        ) or 0.0
        
        # Get errors
        errors = get_metric_statistics(
            'AWS/Lambda',
            'Errors',
            dimensions,
            statistic='Sum'
        ) or 0.0
        
        # Get duration
        duration = get_metric_statistics(
            'AWS/Lambda',
            'Duration',
            dimensions,
            statistic='Average'
        ) or 0.0
        
        # Get throttles
        throttles = get_metric_statistics(
            'AWS/Lambda',
            'Throttles',
            dimensions,
            statistic='Sum'
        ) or 0.0
        
        # Get concurrent executions
        concurrent = get_metric_statistics(
            'AWS/Lambda',
            'ConcurrentExecutions',
            dimensions,
            statistic='Maximum'
        ) or 0.0
        
        # Calculate error rate
        error_rate = (errors / invocations * 100) if invocations > 0 else 0.0
        
        return {
            "invocations": invocations,
            "errors": errors,
            "error_rate": round(error_rate, 2),
            "duration_ms": round(duration, 2),
            "throttles": throttles,
            "concurrent_executions": concurrent
        }
        
    except Exception as e:
        logger.error(f"Error getting Lambda metrics for {function_name}: {e}")
        return {
            "invocations": 0,
            "errors": 0,
            "error_rate": 0.0,
            "duration_ms": 0,
            "throttles": 0,
            "concurrent_executions": 0
        }


def get_cold_path_metrics() -> Dict[str, Any]:
    """
    Get CloudWatch metrics for Cold Path pipeline
    """
    try:
        function_name = LAMBDA_FUNCTIONS['cold_path']
        lambda_metrics = get_lambda_metrics(function_name)
        
        # Get custom metric for API request rate
        api_request_rate = get_metric_statistics(
            f'{PROJECT_NAME.title()}/ColdPath',
            'APIRequestRate',
            [],
            statistic='Average'
        ) or 0.0
        
        # Get repositories processed rate
        repos_processed = get_metric_statistics(
            f'{PROJECT_NAME.title()}/ColdPath',
            'RepositoriesProcessed',
            [],
            statistic='Sum'
        ) or 0.0
        
        return {
            "error_rate": lambda_metrics['error_rate'],
            "api_request_rate": round(api_request_rate, 2),
            "repositories_processed": repos_processed,
            "lambda_duration_ms": lambda_metrics['duration_ms'],
            "lambda_throttles": lambda_metrics['throttles'],
            "lambda_invocations": lambda_metrics['invocations'],
            "lambda_errors": lambda_metrics['errors']
        }
        
    except Exception as e:
        logger.error(f"Error getting Cold Path metrics: {e}")
        return {
            "error_rate": 0.0,
            "api_request_rate": 0.0,
            "repositories_processed": 0,
            "lambda_duration_ms": 0,
            "lambda_throttles": 0
        }


def get_hot_path_metrics() -> Dict[str, Any]:
    """
    Get CloudWatch metrics for Hot Path pipeline
    """
    try:
        # Get metrics for both Hot Path Lambda functions
        poller_metrics = get_lambda_metrics(LAMBDA_FUNCTIONS['hot_path'][0])
        updater_metrics = get_lambda_metrics(LAMBDA_FUNCTIONS['hot_path'][1])
        
        # Get Kinesis metrics
        kinesis_incoming = get_metric_statistics(
            'AWS/Kinesis',
[{'Name': 'StreamName', 'Value': f'{ENVIRONMENT}-{PROJECT_NAME}-events-stream'}],
            statistic='Sum'
        ) or 0.0
        
        kinesis_iterator_age = get_metric_statistics(
            'AWS/Kinesis',
            'GetRecords.IteratorAgeMilliseconds',
            [{'Name': 'StreamName', 'Value': f'{ENVIRONMENT}-{PROJECT_NAME}-events-stream'}],
            statistic='Maximum'
        ) or 0.0
        
        # Calculate average error rate across both functions
        avg_error_rate = (poller_metrics['error_rate'] + updater_metrics['error_rate']) / 2
        
        # Event processing rate (events per minute)
        event_processing_rate = kinesis_incoming / 60  # Convert to per minute
        
        return {
            "error_rate": round(avg_error_rate, 2),
            "event_processing_rate": round(event_processing_rate, 2),
            "kinesis_incoming_records": kinesis_incoming,
            "kinesis_iterator_age_ms": round(kinesis_iterator_age, 2),
            "poller_lambda": {
                "duration_ms": poller_metrics['duration_ms'],
                "throttles": poller_metrics['throttles'],
                "invocations": poller_metrics['invocations'],
                "errors": poller_metrics['errors']
            },
            "updater_lambda": {
                "duration_ms": updater_metrics['duration_ms'],
                "throttles": updater_metrics['throttles'],
                "invocations": updater_metrics['invocations'],
                "errors": updater_metrics['errors']
            }
        }
        
    except Exception as e:
        logger.error(f"Error getting Hot Path metrics: {e}")
        return {
            "error_rate": 0.0,
            "event_processing_rate": 0.0,
            "kinesis_incoming_records": 0,
            "kinesis_iterator_age_ms": 0
        }


def get_scrubber_path_metrics() -> Dict[str, Any]:
    """
    Get CloudWatch metrics for Scrubber Path pipeline
    """
    try:
        function_name = LAMBDA_FUNCTIONS['scrubber_path']
        lambda_metrics = get_lambda_metrics(function_name)
        
        # Get SQS metrics
        sqs_messages_sent = get_metric_statistics(
            'AWS/SQS',
            'NumberOfMessagesSent',
            [{'Name': 'QueueName', 'Value': f'{ENVIRONMENT}-{PROJECT_NAME}-scrubber-queue'}],
            statistic='Sum'
        ) or 0.0
        
        sqs_messages_deleted = get_metric_statistics(
            'AWS/SQS',
            'NumberOfMessagesDeleted',
            [{'Name': 'QueueName', 'Value': f'{ENVIRONMENT}-{PROJECT_NAME}-scrubber-queue'}],
            statistic='Sum'
        ) or 0.0
        
        # Validation rate is the number of Lambda invocations (each processes a batch)
        validation_rate = lambda_metrics['invocations']
        
        return {
            "error_rate": lambda_metrics['error_rate'],
            "validation_rate": validation_rate,
            "sqs_messages_sent": sqs_messages_sent,
            "sqs_messages_deleted": sqs_messages_deleted,
            "lambda_duration_ms": lambda_metrics['duration_ms'],
            "lambda_throttles": lambda_metrics['throttles'],
            "lambda_invocations": lambda_metrics['invocations'],
            "lambda_errors": lambda_metrics['errors']
        }
        
    except Exception as e:
        logger.error(f"Error getting Scrubber Path metrics: {e}")
        return {
            "error_rate": 0.0,
            "validation_rate": 0.0,
            "lambda_duration_ms": 0,
            "lambda_throttles": 0
        }


def get_overall_system_metrics() -> Dict[str, Any]:
    """
    Get overall system-wide metrics
    """
    try:
        # Get all Lambda functions in the environment
        all_functions = []
        paginator = lambda_client.get_paginator('list_functions')
        
        for page in paginator.paginate():
            for func in page['Functions']:
                if func['FunctionName'].startswith(f'{ENVIRONMENT}-{PROJECT_NAME}'):
                    all_functions.append(func['FunctionName'])
        
        # Calculate aggregate metrics
        total_invocations = 0
        total_errors = 0
        total_throttles = 0
        
        for func_name in all_functions:
            metrics = get_lambda_metrics(func_name)
            total_invocations += metrics['invocations']
            total_errors += metrics['errors']
            total_throttles += metrics['throttles']
        
        overall_error_rate = (total_errors / total_invocations * 100) if total_invocations > 0 else 0.0
        
        return {
            "total_lambda_functions": len(all_functions),
            "total_invocations": total_invocations,
            "total_errors": total_errors,
            "total_throttles": total_throttles,
            "overall_error_rate": round(overall_error_rate, 2)
        }
        
    except Exception as e:
        logger.error(f"Error getting overall system metrics: {e}")
        return {
            "total_lambda_functions": 0,
            "total_invocations": 0,
            "total_errors": 0,
            "total_throttles": 0,
            "overall_error_rate": 0.0
        }


def lambda_handler(event, context):
    """
    API Gateway handler for /api/metrics/cloudwatch endpoint
    Returns CloudWatch metrics for all pipelines
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Get metrics for all pipelines
        cold_path = get_cold_path_metrics()
        hot_path = get_hot_path_metrics()
        scrubber_path = get_scrubber_path_metrics()
        overall = get_overall_system_metrics()
        
        response = {
            "cold_path": cold_path,
            "hot_path": hot_path,
            "scrubber_path": scrubber_path,
            "overall": overall,
            "timestamp": datetime.utcnow().isoformat(),
            "period": "last_1_hour"
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
