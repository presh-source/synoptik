"""
Realtime Metrics Lambda
Queries OpenSearch for trending repositories and real-time metrics
"""
import json
import os
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from urllib.parse import urlparse
import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
OPENSEARCH_ENDPOINT = os.environ.get('OPENSEARCH_ENDPOINT', '')
ENVIRONMENT = os.environ.get('ENVIRONMENT', '')
AWS_REGION = os.environ.get('AWS_REGION', '')

# Initialize AWS credentials for OpenSearch
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    AWS_REGION,
    'es',
    session_token=credentials.token
)

# Parse OpenSearch endpoint
parsed_url = urlparse(f"https://{OPENSEARCH_ENDPOINT}" if not OPENSEARCH_ENDPOINT.startswith('http') else OPENSEARCH_ENDPOINT)
opensearch_host = parsed_url.hostname or OPENSEARCH_ENDPOINT

# Initialize OpenSearch client
opensearch_client = OpenSearch(
    hosts=[{'host': opensearch_host, 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection
) if OPENSEARCH_ENDPOINT else None


def get_trending_repositories(hours: int = 24, limit: int = 10) -> List[Dict[str, Any]]:
    """
    Query OpenSearch for top repositories by stars in the last N hours
    """
    if not opensearch_client:
        logger.warning("OpenSearch client not initialized")
        return []
    
    try:
        # Calculate time range
        now = datetime.utcnow()
        start_time = now - timedelta(hours=hours)
        
        # Query for repositories with recent star activity
        query = {
            "size": limit,
            "query": {
                "bool": {
                    "must": [
                        {"term": {"is_deleted": False}}
                    ],
                    "filter": [
                        {
                            "range": {
                                "pushed_at": {
                                    "gte": start_time.isoformat(),
                                    "lte": now.isoformat()
                                }
                            }
                        }
                    ]
                }
            },
            "sort": [
                {"stargazers_count": {"order": "desc"}}
            ],
            "_source": [
                "id", "full_name", "description", "language", 
                "stargazers_count", "forks_count", "watchers_count",
                "created_at", "pushed_at"
            ]
        }
        
        response = opensearch_client.search(
            index="repositories",
            body=query
        )
        
        trending = []
        for hit in response['hits']['hits']:
            repo = hit['_source']
            trending.append({
                "id": repo.get('id'),
                "full_name": repo.get('full_name'),
                "description": repo.get('description'),
                "language": repo.get('language'),
                "stargazers_count": repo.get('stargazers_count', 0),
                "forks_count": repo.get('forks_count', 0),
                "watchers_count": repo.get('watchers_count', 0),
                "created_at": repo.get('created_at'),
                "pushed_at": repo.get('pushed_at')
            })
        
        return trending
        
    except Exception as e:
        logger.error(f"Error querying trending repositories: {e}", exc_info=True)
        return []


def get_repositories_by_language(language_filter: Optional[str] = None) -> Dict[str, int]:
    """
    Query OpenSearch for repository count by programming language
    """
    if not opensearch_client:
        logger.warning("OpenSearch client not initialized")
        return {}
    
    try:
        query = {
            "size": 0,
            "query": {
                "bool": {
                    "must": [
                        {"term": {"is_deleted": False}}
                    ]
                }
            },
            "aggs": {
                "languages": {
                    "terms": {
                        "field": "language",
                        "size": 50,
                        "order": {"_count": "desc"}
                    }
                }
            }
        }
        
        # Add language filter if specified
        if language_filter:
            query["query"]["bool"]["must"].append(
                {"term": {"language": language_filter}}
            )
        
        response = opensearch_client.search(
            index="repositories",
            body=query
        )
        
        languages = {}
        for bucket in response['aggregations']['languages']['buckets']:
            languages[bucket['key']] = bucket['doc_count']
        
        return languages
        
    except Exception as e:
        logger.error(f"Error querying repositories by language: {e}", exc_info=True)
        return {}


def get_repositories_by_license(license_filter: Optional[str] = None) -> Dict[str, int]:
    """
    Query OpenSearch for repository count by license
    """
    if not opensearch_client:
        logger.warning("OpenSearch client not initialized")
        return {}
    
    try:
        query = {
            "size": 0,
            "query": {
                "bool": {
                    "must": [
                        {"term": {"is_deleted": False}}
                    ]
                }
            },
            "aggs": {
                "licenses": {
                    "terms": {
                        "field": "license_name",
                        "size": 30,
                        "order": {"_count": "desc"}
                    }
                }
            }
        }
        
        # Add license filter if specified
        if license_filter:
            query["query"]["bool"]["must"].append(
                {"term": {"license_name": license_filter}}
            )
        
        response = opensearch_client.search(
            index="repositories",
            body=query
        )
        
        licenses = {}
        for bucket in response['aggregations']['licenses']['buckets']:
            licenses[bucket['key']] = bucket['doc_count']
        
        return licenses
        
    except Exception as e:
        logger.error(f"Error querying repositories by license: {e}", exc_info=True)
        return {}


def get_creation_trends(days: int = 30, language_filter: Optional[str] = None, 
                       license_filter: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Query OpenSearch for repository creation trends over time
    """
    if not opensearch_client:
        logger.warning("OpenSearch client not initialized")
        return []
    
    try:
        # Calculate time range
        now = datetime.utcnow()
        start_time = now - timedelta(days=days)
        
        query = {
            "size": 0,
            "query": {
                "bool": {
                    "must": [
                        {"term": {"is_deleted": False}}
                    ],
                    "filter": [
                        {
                            "range": {
                                "created_at": {
                                    "gte": start_time.isoformat(),
                                    "lte": now.isoformat()
                                }
                            }
                        }
                    ]
                }
            },
            "aggs": {
                "creation_by_day": {
                    "date_histogram": {
                        "field": "created_at",
                        "calendar_interval": "day",
                        "format": "yyyy-MM-dd",
                        "min_doc_count": 0
                    }
                }
            }
        }
        
        # Add filters if specified
        if language_filter:
            query["query"]["bool"]["must"].append(
                {"term": {"language": language_filter}}
            )
        
        if license_filter:
            query["query"]["bool"]["must"].append(
                {"term": {"license_name": license_filter}}
            )
        
        response = opensearch_client.search(
            index="repositories",
            body=query
        )
        
        trends = []
        for bucket in response['aggregations']['creation_by_day']['buckets']:
            trends.append({
                "date": bucket['key_as_string'],
                "count": bucket['doc_count']
            })
        
        return trends
        
    except Exception as e:
        logger.error(f"Error querying creation trends: {e}", exc_info=True)
        return []


def get_total_repositories(language_filter: Optional[str] = None, 
                          license_filter: Optional[str] = None) -> int:
    """
    Get total count of repositories with optional filters
    """
    if not opensearch_client:
        logger.warning("OpenSearch client not initialized")
        return 0
    
    try:
        query = {
            "query": {
                "bool": {
                    "must": [
                        {"term": {"is_deleted": False}}
                    ]
                }
            }
        }
        
        # Add filters if specified
        if language_filter:
            query["query"]["bool"]["must"].append(
                {"term": {"language": language_filter}}
            )
        
        if license_filter:
            query["query"]["bool"]["must"].append(
                {"term": {"license_name": license_filter}}
            )
        
        response = opensearch_client.count(
            index="repositories",
            body=query
        )
        
        return response['count']
        
    except Exception as e:
        logger.error(f"Error counting repositories: {e}", exc_info=True)
        return 0


def lambda_handler(event, context):
    """
    API Gateway handler for /api/metrics/realtime and /api/metrics/trending endpoints
    Returns real-time metrics from OpenSearch
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Get path to determine which endpoint was called
        path = event.get('path', '')
        query_params = event.get('queryStringParameters') or {}
        
        # Extract query parameters
        language = query_params.get('language')
        license_name = query_params.get('license')
        start_date = query_params.get('startDate')
        end_date = query_params.get('endDate')
        
        # Calculate days for trends
        days = 30  # Default
        if start_date and end_date:
            try:
                start = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
                end = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
                days = (end - start).days
            except Exception as e:
                logger.warning(f"Could not parse date range: {e}")
        
        # Route to appropriate handler
        if 'trending' in path:
            # GET /api/metrics/trending
            trending = get_trending_repositories(hours=24, limit=10)
            response = {
                "trending_repositories": trending,
                "timestamp": datetime.utcnow().isoformat()
            }
        else:
            # GET /api/metrics/realtime
            total = get_total_repositories(language, license_name)
            languages = get_repositories_by_language(language)
            licenses = get_repositories_by_license(license_name)
            trends = get_creation_trends(days, language, license_name)
            
            response = {
                "total_repositories": total,
                "repositories_by_language": languages,
                "repositories_by_license": licenses,
                "creation_trends": trends,
                "filters": {
                    "language": language,
                    "license": license_name,
                    "days": days
                },
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
