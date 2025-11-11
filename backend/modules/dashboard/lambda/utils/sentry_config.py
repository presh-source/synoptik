"""
Sentry configuration for Lambda functions
"""

import os
import sentry_sdk
from sentry_sdk.integrations.aws_lambda import AwsLambdaIntegration


def init_sentry():
    """
    Initialize Sentry for Lambda functions

    Environment variables required:
    - SENTRY_DSN: Sentry Data Source Name
    - ENVIRONMENT: Environment name (dev, staging, prod)
    - VERSION: Application version for release tracking
    """
    sentry_dsn = os.environ.get("SENTRY_DSN")

    if not sentry_dsn:
        print("Sentry DSN not configured, skipping initialization")
        return

    sentry_sdk.init(
        dsn=sentry_dsn,
        # AWS Lambda integration
        integrations=[
            AwsLambdaIntegration(
                timeout_warning=True  # Warn when Lambda is about to timeout
            ),
        ],
        # Performance Monitoring
        traces_sample_rate=float(os.environ.get("SENTRY_TRACES_SAMPLE_RATE", "0.1")),
        # Environment
        environment=os.environ.get("ENVIRONMENT", "dev"),
        # Release tracking
        release=f"synoptik-backend@{os.environ.get('VERSION', '1.0.0')}",
        # Additional options
        attach_stacktrace=True,  # Attach stack traces to messages
        send_default_pii=False,  # Don't send personally identifiable information
        # Set server name to Lambda function name
        server_name=os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "unknown"),
        # Custom tags
        _experiments={
            "profiles_sample_rate": 0.1,  # Profile 10% of transactions
        },
    )

    # Set custom tags
    sentry_sdk.set_tag(
        "lambda.function_name", os.environ.get("AWS_LAMBDA_FUNCTION_NAME")
    )
    sentry_sdk.set_tag("lambda.region", os.environ.get("AWS_REGION"))
    sentry_sdk.set_tag(
        "lambda.memory", os.environ.get("AWS_LAMBDA_FUNCTION_MEMORY_SIZE")
    )

    print(f"Sentry initialized for {os.environ.get('AWS_LAMBDA_FUNCTION_NAME')}")


def capture_lambda_error(error, context=None, extra_context=None):
    """
    Capture Lambda errors with context

    Args:
        error: The exception to capture
        context: AWS Lambda context object
        extra_context: Additional context dictionary
    """
    with sentry_sdk.push_scope() as scope:
        # Add Lambda context
        if context:
            scope.set_context(
                "lambda",
                {
                    "function_name": context.function_name,
                    "function_version": context.function_version,
                    "invoked_function_arn": context.invoked_function_arn,
                    "memory_limit_mb": context.memory_limit_in_mb,
                    "request_id": context.aws_request_id,
                    "log_group_name": context.log_group_name,
                    "log_stream_name": context.log_stream_name,
                },
            )

        # Add extra context
        if extra_context:
            scope.set_context("extra", extra_context)

        # Capture the exception
        sentry_sdk.capture_exception(error)


def add_breadcrumb(message, category="lambda", level="info", data=None):
    """
    Add a breadcrumb to track execution flow

    Args:
        message: Breadcrumb message
        category: Category (e.g., 'lambda', 'database', 'api')
        level: Severity level ('debug', 'info', 'warning', 'error')
        data: Additional data dictionary
    """
    sentry_sdk.add_breadcrumb(
        category=category, message=message, level=level, data=data or {}
    )


def set_user_context(user_id=None, email=None, username=None, extra=None):
    """
    Set user context for error tracking

    Args:
        user_id: User ID
        email: User email
        username: Username
        extra: Additional user data
    """
    user_data = {}
    if user_id:
        user_data["id"] = user_id
    if email:
        user_data["email"] = email
    if username:
        user_data["username"] = username
    if extra:
        user_data.update(extra)

    if user_data:
        sentry_sdk.set_user(user_data)


def capture_message(message, level="info", extra=None):
    """
    Capture a message (not an exception)

    Args:
        message: Message to capture
        level: Severity level ('debug', 'info', 'warning', 'error', 'fatal')
        extra: Additional context
    """
    with sentry_sdk.push_scope() as scope:
        if extra:
            scope.set_context("extra", extra)
        sentry_sdk.capture_message(message, level=level)
