# Tasks

## Refactor Flat Repo Structure and Generate Owner Node Identifier

-   Trim fields from `current_flat_repo` to produce `desired_flat_repo`
    containing only:

    -   `id`, `node_id`, `name`, `full_name`, `private`
    -   `owner_id`, `owner_node_id`
    -   `description`, `fork`

-   Use **AWS Glue ETL** to remove unused columns and reshape the repo
    data.

-   Extract the owner's numeric ID from `repo["owner"]["id"]`.

-   Construct `owner_node_id` using the required format:

        04::User:<numeric_id>

    **Where:**

    -   **04** → constant prefix for a User\
    -   **::** → separator\
    -   **User** → object type\
    -   **`<numeric_id>`{=html}** → owner's numeric GitHub ID

-   Insert `owner_node_id` into `desired_flat_repo`.

------------------------------------------------------------------------

## Metrics & Monitoring

-   Add metrics for the **user and repo crawler**:
    -   per hour\
    -   per minute\
    -   per second\
    -   track runs for:
        -   repo crawler\
        -   user crawler\
        -   request counts
-   Update **cloudwatch_metrics** and **pipeline_status** to include new
    metric dimensions.

## Terraform Infrastructure

-   Create a **Terraform API module** and migrate existing API Gateway
    configuration into it.
-   Create a **Terraform module for domain_name and certificate**, and
    move:
    -   DNS configuration\
    -   Route53 records\
    -   ACM certificates

## GraphQL Integration

-   Replace API Gateway's usage with **GraphQL** for:
    -   cloudwatch_metrics\
    -   pipeline_status
-   Ensure GraphQL schema exposes monitoring and pipeline status fields
    previously provided via API Gateway.
