"""
Real-Time Metrics Lambda Function
Returns trending repositories, language distribution, and creation trends
"""

import json
from datetime import datetime, timedelta
from utils.sentry_config import init_sentry, capture_lambda_error, add_breadcrumb

# Initialize Sentry
init_sentry()


def lambda_handler(event, context):
    """
    Lambda handler for real-time metrics endpoint

    Query parameters:
        - language: Filter by programming language
        - license: Filter by license type
        - dateFrom: Start date for filtering
        - dateTo: End date for filtering

    Returns:
        dict: API Gateway response with metrics data
    """
    add_breadcrumb(
        message="Real-time metrics request received",
        category="lambda",
        level="info",
        data={"event": event},
    )

    try:
        # Parse query parameters
        query_params = event.get("queryStringParameters") or {}

        add_breadcrumb(
            message="Parsing query parameters",
            category="lambda",
            level="info",
            data={"params": query_params},
        )

        # Get metrics data
        metrics = get_realtime_metrics(query_params)

        add_breadcrumb(
            message="Metrics retrieved successfully", category="lambda", level="info"
        )

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "GET,OPTIONS",
            },
            "body": json.dumps(metrics),
        }

    except Exception as e:
        # Capture error with context
        capture_lambda_error(
            e,
            context,
            extra_context={
                "endpoint": "realtime-metrics",
                "query_params": query_params,
                "event": event,
            },
        )

        # Return error response
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps(
                {
                    "error": "Internal server error",
                    "message": str(e),
                    "request_id": context.request_id if context else None,
                }
            ),
        }


def get_realtime_metrics(filters):
    """
    Get real-time metrics with optional filters

    Args:
        filters: Dictionary of filter parameters

    Returns:
        dict: Metrics data
    """
    add_breadcrumb(
        message="Fetching real-time metrics",
        category="database",
        level="info",
        data={"filters": filters},
    )

    # Mock data for now - replace with actual OpenSearch queries
    # In production, this would query OpenSearch for real data

    metrics = {
        "trendingRepositories": [
            {
                "id": 1,
                "fullName": "facebook/react",
                "description": "A declarative, efficient, and flexible JavaScript library",
                "language": "JavaScript",
                "stargazersCount": 220000,
                "forksCount": 45000,
                "starsLast24h": 150,
            },
            {
                "id": 2,
                "fullName": "microsoft/vscode",
                "description": "Visual Studio Code",
                "language": "TypeScript",
                "stargazersCount": 155000,
                "forksCount": 27000,
                "starsLast24h": 120,
            },
            {
                "id": 3,
                "fullName": "python/cpython",
                "description": "The Python programming language",
                "language": "Python",
                "stargazersCount": 58000,
                "forksCount": 28000,
                "starsLast24h": 95,
            },
        ],
        "languageDistribution": [
            {"language": "JavaScript", "count": 350000, "percentage": 35.0},
            {"language": "Python", "count": 250000, "percentage": 25.0},
            {"language": "Java", "count": 150000, "percentage": 15.0},
            {"language": "TypeScript", "count": 100000, "percentage": 10.0},
            {"language": "Go", "count": 80000, "percentage": 8.0},
            {"language": "Rust", "count": 70000, "percentage": 7.0},
        ],
        "creationTrends": generate_creation_trends(),
    }

    return metrics


def generate_creation_trends():
    """
    Generate repository creation trends for the last 30 days

    Returns:
        list: Daily creation counts
    """
    trends = []
    base_date = datetime.utcnow() - timedelta(days=30)

    for i in range(30):
        date = base_date + timedelta(days=i)
        trends.append(
            {
                "date": date.strftime("%Y-%m-%d"),
                "count": 5000 + (i * 100),  # Mock increasing trend
            }
        )

    return trends
