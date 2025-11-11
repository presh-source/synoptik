# Synoptik

A comprehensive data platform that creates a queryable digital twin of GitHub's public repository ecosystem, enabling real-time analytics and insights.

## Overview

The Synoptik platform ingests, processes, and analyzes GitHub's public repository data through three specialized pipelines:

- **Cold Path**: Historical data ingestion from GitHub Archive
- **Hot Path**: Real-time event processing via GitHub webhooks
- **Scrubber Path**: Deletion detection and data cleanup

## Features

- 📊 **Real-time Analytics**: Query repository trends, language distributions, and ecosystem metrics
- 🔍 **Graph Relationships**: Explore repository dependencies and contributor networks
- 📈 **Observability Dashboard**: Monitor pipeline health and system metrics
- 🔄 **Continuous Sync**: Stay up-to-date with GitHub's latest changes
- 🧹 **Data Quality**: Automatic detection and cleanup of deleted repositories

## Architecture

The platform uses a modern cloud-native architecture:

- **Data Lake**: S3 for raw data storage
- **Search Engine**: OpenSearch for full-text search and analytics
- **Graph Database**: Neptune for relationship queries
- **Stream Processing**: Kinesis for real-time event handling
- **Serverless Compute**: Lambda for data processing
- **API Layer**: API Gateway for RESTful access
- **Frontend**: React dashboard for visualization

## Quick Start

### Local Development with LocalStack

The fastest way to get started is using LocalStack for local development:

```bash
# 1. Clone the repository
git clone <repository-url>
cd synoptik

# 2. Start LocalStack and deploy everything
./localstack-start.sh
```

This will:
- Start LocalStack with all required AWS services
- Deploy infrastructure with Terraform
- Build and deploy the dashboard
- Set up all pipelines

Access the dashboard at: http://localhost:4566/synoptik-dashboard-local/index.html

For detailed LocalStack setup, see [LOCALSTACK_SETUP.md](./LOCALSTACK_SETUP.md)

### AWS Deployment

For production deployment to AWS:

1. **Prerequisites**
   - AWS account with appropriate permissions
   - Terraform >= 1.5.0
   - AWS CLI configured
   - GitHub Personal Access Token

2. **Deploy Infrastructure**
   ```bash
   cd terraform
   export TF_VAR_github_token="your_github_token"
   terraform init -backend-config=environments/dev/backend.tfvars
   terraform apply -var-file=environments/dev/terraform.tfvars
   ```

3. **Deploy Dashboard**
   ```bash
   cd dashboard
   ./deploy.sh
   ```

See [terraform/README.md](./terraform/README.md) for detailed deployment instructions.

## Project Structure

```
synoptik/
├── terraform/                  # Infrastructure as Code
│   ├── modules/               # Terraform modules
│   │   ├── cold-path/        # Historical ingestion pipeline
│   │   ├── hot-path/         # Real-time event pipeline
│   │   ├── scrubber-path/    # Deletion detection pipeline
│   │   ├── data-stores/      # OpenSearch, Neptune, Athena
│   │   ├── dashboard/        # API Gateway, Lambda, frontend
│   │   └── ...
│   └── environments/         # Environment configs (dev/staging/prod/local)
├── dashboard/                 # React frontend application
│   ├── src/
│   │   ├── components/       # UI components
│   │   ├── pages/            # Dashboard pages
│   │   ├── api/              # API client
│   │   └── ...
│   ├── deploy.sh             # AWS deployment script
│   └── deploy-localstack.sh  # LocalStack deployment script
├── docker-compose.localstack.yml  # LocalStack configuration
├── localstack-start.sh       # Quick start script
└── LOCALSTACK_SETUP.md       # LocalStack setup guide
```

## Development

### Prerequisites

- **Docker**: For LocalStack
- **Terraform**: >= 1.5.0
- **Node.js**: >= 18.x
- **Python**: >= 3.9 (for Lambda functions)
- **AWS CLI**: For AWS/LocalStack interaction

### Local Development Workflow

1. **Start LocalStack**
   ```bash
   docker-compose -f docker-compose.localstack.yml up -d
   ```

2. **Deploy Infrastructure**
   ```bash
   cd terraform
   export USE_LOCALSTACK=true
   terraform apply -var-file=environments/local/terraform.tfvars -auto-approve
   ```

3. **Run Dashboard Locally**
   ```bash
   cd dashboard
   npm install
   npm run dev
   ```

4. **Make Changes and Test**
   - Edit code
   - Test locally
   - Deploy to LocalStack

5. **View Logs**
   ```bash
   docker-compose -f docker-compose.localstack.yml logs -f
   ```

### Testing

```bash
# Run dashboard tests
cd dashboard
npm test

# Run Lambda function tests
cd terraform/modules/cold-path/lambda
python -m pytest
```

## Documentation

- [LocalStack Setup Guide](./LOCALSTACK_SETUP.md) - Local development with LocalStack
- [Terraform README](./terraform/README.md) - Infrastructure deployment
- [Dashboard README](./dashboard/README.md) - Frontend application
- [Dashboard Deployment](./dashboard/DEPLOYMENT.md) - AWS deployment guide
- [Design Document](./.kiro/specs/synoptik/design.md) - Architecture and design
- [Requirements](./.kiro/specs/synoptik/requirements.md) - System requirements

## Pipelines

### Cold Path (Historical Ingestion)

Ingests historical repository data from GitHub Archive:
- Processes repositories sequentially by ID
- Stores raw data in S3 Data Lake
- Indexes in OpenSearch for search
- Loads relationships into Neptune
- Tracks progress in DynamoDB

### Hot Path (Real-time Events)

Processes real-time GitHub events:
- Receives webhooks from GitHub
- Streams through Kinesis
- Updates OpenSearch and Neptune in real-time
- Handles repository updates, stars, forks, etc.

### Scrubber Path (Data Cleanup)

Maintains data quality:
- Detects deleted repositories
- Validates repository existence
- Cleans up stale data
- Runs weekly via EventBridge

## Observability Dashboard

The dashboard provides real-time monitoring:

### Pipeline Status
- Cold Path progress and ingestion rate
- Hot Path event processing metrics
- Scrubber Path queue depth and validation rate
- Error rates and health indicators

### Real-Time Metrics
- Trending repositories (24h growth)
- Language distribution
- Repository creation trends
- Filterable by language, license, date range

## API Endpoints

The platform exposes RESTful APIs:

- `GET /api/pipeline-status` - Pipeline health and metrics
- `GET /api/metrics/realtime` - Real-time ecosystem metrics
- `GET /api/repositories/trending` - Trending repositories
- `GET /api/repositories/search` - Search repositories
- `GET /api/repositories/{id}` - Get repository details

## Cost Optimization

The platform is designed for cost efficiency:

- **Serverless Architecture**: Pay only for what you use
- **S3 Lifecycle Policies**: Automatic data archival
- **Reserved Capacity**: For predictable workloads
- **Spot Instances**: For batch processing
- **CloudFront Caching**: Reduced API calls

Estimated monthly cost: $200-500 depending on scale

## Security

- **Encryption**: All data encrypted at rest and in transit
- **IAM Roles**: Least privilege access control
- **VPC**: Private subnets for databases
- **Secrets Manager**: Secure token storage
- **API Gateway**: Rate limiting and throttling

## Monitoring

- **CloudWatch Dashboards**: System metrics and logs
- **CloudWatch Alarms**: Automated alerting
- **X-Ray Tracing**: Distributed tracing
- **Custom Metrics**: Pipeline-specific monitoring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with LocalStack
5. Submit a pull request

## License

[Your License Here]

## Support

For issues and questions:
- Check documentation in this repository
- Review [LOCALSTACK_SETUP.md](./LOCALSTACK_SETUP.md) for local development
- Check [terraform/README.md](./terraform/README.md) for infrastructure issues

## Roadmap

- [ ] Machine learning for repository recommendations
- [ ] Advanced graph analytics
- [ ] Multi-region deployment
- [ ] Real-time collaboration features
- [ ] Enhanced security scanning
- [ ] API rate limiting per user
- [ ] Custom dashboard widgets

## Acknowledgments

- GitHub Archive for historical data
- LocalStack for local AWS emulation
- OpenSearch for search capabilities
- AWS for cloud infrastructure
