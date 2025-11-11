# Dashboard Deployment Guide

This guide covers deploying the Synoptik Dashboard to AWS using S3 and CloudFront.

## Architecture

The dashboard is deployed as a static website with the following components:

- **S3 Bucket**: Hosts the built React application files
- **CloudFront Distribution**: CDN for global content delivery with HTTPS
- **Origin Access Identity (OAI)**: Secures S3 bucket access through CloudFront only

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed and configured
3. **AWS CLI** installed and configured
4. **Node.js 18+** and npm installed

## Infrastructure Setup

### 1. Deploy Infrastructure with Terraform

First, deploy the infrastructure using Terraform:

```bash
cd terraform

# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

This will create:
- S3 bucket for hosting the dashboard
- CloudFront distribution with OAI
- Necessary IAM policies and permissions

### 2. Get Deployment Information

After Terraform applies successfully, get the deployment information:

```bash
# Get S3 bucket name
terraform output dashboard_bucket_name

# Get CloudFront distribution ID
terraform output cloudfront_distribution_id

# Get dashboard URL
terraform output dashboard_url
```

## Application Deployment

### Manual Deployment

Use the provided deployment script:

```bash
cd dashboard

# Deploy to dev environment (default)
./deploy.sh

# Deploy to specific environment
./deploy.sh prod
```

The script will:
1. Install dependencies
2. Build the React application
3. Upload files to S3
4. Invalidate CloudFront cache

### Manual Steps

If you prefer to deploy manually:

```bash
cd dashboard

# Install dependencies
npm install --legacy-peer-deps

# Build the application
npm run build

# Upload to S3 (replace BUCKET_NAME)
aws s3 sync dist/ s3://BUCKET_NAME/ \
  --delete \
  --cache-control "public, max-age=31536000, immutable" \
  --exclude "index.html"

# Upload index.html with no-cache
aws s3 cp dist/index.html s3://BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# Invalidate CloudFront cache (replace DISTRIBUTION_ID)
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"
```

## CI/CD with GitHub Actions

The repository includes a GitHub Actions workflow for automated deployments.

### Setup

1. Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`: AWS access key
   - `AWS_SECRET_ACCESS_KEY`: AWS secret key
   - `API_URL`: Backend API URL

2. The workflow triggers on:
   - Push to `main` or `develop` branches (when dashboard files change)
   - Manual workflow dispatch

### Manual Trigger

To manually trigger a deployment:

1. Go to Actions tab in GitHub
2. Select "Deploy Dashboard" workflow
3. Click "Run workflow"
4. Select environment (dev/staging/prod)
5. Click "Run workflow"

## Environment Configuration

### Environment Variables

Create a `.env` file in the dashboard directory:

```bash
VITE_API_URL=https://your-api-gateway-url.amazonaws.com/api
```

For production, set this in your CI/CD pipeline or build process.

### API Gateway Integration

The dashboard expects the backend API to be available at the configured `VITE_API_URL`. Ensure:

1. API Gateway is deployed and accessible
2. CORS is properly configured on API Gateway
3. API endpoints match those defined in `src/api/endpoints.ts`

## Custom Domain Setup (Optional)

To use a custom domain with SSL:

### 1. Request ACM Certificate

```bash
# Request certificate in us-east-1 (required for CloudFront)
aws acm request-certificate \
  --domain-name dashboard.yourdomain.com \
  --validation-method DNS \
  --region us-east-1
```

### 2. Update Terraform Variables

Add to your `terraform.tfvars`:

```hcl
custom_domain_name = "dashboard.yourdomain.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID"
```

### 3. Update CloudFront Configuration

Uncomment the custom domain section in `terraform/modules/dashboard/frontend.tf`:

```hcl
viewer_certificate {
  acm_certificate_arn      = var.acm_certificate_arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
}

aliases = [var.custom_domain_name]
```

### 4. Update DNS

Add a CNAME record pointing to the CloudFront distribution domain name.

## Monitoring and Troubleshooting

### CloudWatch Logs

CloudFront access logs are stored in CloudWatch Logs:

```bash
aws logs tail /aws/cloudfront/synoptik-dashboard --follow
```

### Common Issues

**Issue: 403 Forbidden**
- Check S3 bucket policy allows CloudFront OAI access
- Verify CloudFront distribution is enabled

**Issue: Stale content after deployment**
- Ensure CloudFront cache invalidation completed
- Check cache-control headers on S3 objects

**Issue: API calls failing**
- Verify VITE_API_URL is set correctly
- Check API Gateway CORS configuration
- Verify API Gateway is deployed and accessible

### Cache Invalidation

To manually invalidate CloudFront cache:

```bash
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"
```

## Performance Optimization

### Build Optimization

The Vite build is already optimized with:
- Code splitting
- Tree shaking
- Minification
- Asset optimization

### CloudFront Configuration

Current settings:
- Compression enabled
- Price class: North America and Europe only
- Default TTL: 1 hour
- Max TTL: 24 hours

To adjust, modify `terraform/modules/dashboard/frontend.tf`.

## Security Considerations

1. **S3 Bucket**: Not publicly accessible, only through CloudFront
2. **HTTPS**: All traffic redirected to HTTPS
3. **Origin Access Identity**: Restricts S3 access to CloudFront only
4. **Versioning**: Enabled on S3 bucket for rollback capability

## Rollback Procedure

If a deployment causes issues:

### 1. Rollback S3 Content

```bash
# List previous versions
aws s3api list-object-versions --bucket BUCKET_NAME

# Restore specific version
aws s3api copy-object \
  --copy-source BUCKET_NAME/index.html?versionId=VERSION_ID \
  --bucket BUCKET_NAME \
  --key index.html
```

### 2. Invalidate CloudFront Cache

```bash
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"
```

## Cost Estimation

Approximate monthly costs (varies by usage):

- **S3 Storage**: $0.023/GB (~$0.50 for typical dashboard)
- **CloudFront**: $0.085/GB for first 10TB + $0.01 per 10,000 requests
- **Data Transfer**: Varies by region and volume

Typical monthly cost: $5-20 depending on traffic.

## Support

For issues or questions:
1. Check CloudWatch Logs for errors
2. Review Terraform state for infrastructure issues
3. Verify API Gateway connectivity
4. Check GitHub Actions logs for CI/CD issues
