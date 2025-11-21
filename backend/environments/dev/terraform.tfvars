# Development Environment Configuration

environment         = "dev"
domain_name         = "dev.synoptik.dev"
api_domain_name     = "api.dev.synoptik.dev"
graphql_domain_name = "graphql.dev.synoptik.dev"
hosted_zone_name    = "synoptik.dev"

# AppSync GraphQL endpoint for crawler event publishing
# This should be set after the dashboard module is deployed
# Get the value from: terraform output -module=dashboard appsync_graphql_api_url
# Example: appsync_graphql_endpoint = "https://xxxxx.appsync-api.us-east-1.amazonaws.com/graphql"
appsync_graphql_endpoint = ""


