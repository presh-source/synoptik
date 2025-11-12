# Custom Domain Setup Guide for Synoptik Dashboard

This guide walks you through setting up a custom domain from Namecheap (or any registrar) for your Synoptik dashboard hosted on CloudFront.

## Prerequisites

- A domain purchased from Namecheap (e.g., `synoptik.com`)
- AWS account with Route53 access
- Terraform configured and working

## Option 1: Using AWS Route53 (Recommended)

This is the easiest approach as Terraform will automatically handle DNS validation and setup.

### Step 1: Transfer DNS Management to Route53

1. **Create a Hosted Zone in Route53**:
   ```bash
   aws route53 create-hosted-zone \
     --name synoptik.com \
     --caller-reference $(date +%s)
   ```

2. **Get the Route53 Name Servers**:
   ```bash
   aws route53 get-hosted-zone --id <HOSTED_ZONE_ID>
   ```
   
   You'll see something like:
   ```
   ns-123.awsdns-12.com
   ns-456.awsdns-45.net
   ns-789.awsdns-78.org
   ns-012.awsdns-01.co.uk
   ```

3. **Update Namecheap DNS Settings**:
   - Go to [Namecheap Dashboard](https://ap.www.namecheap.com/domains/list/)
   - Click **Manage** next to your domain
   - Go to **Domain** tab
   - Under **NAMESERVERS**, select **Custom DNS**
   - Add all 4 Route53 nameservers
   - Click **Save**
   - **Wait 24-48 hours** for DNS propagation

### Step 2: Update Terraform Configuration

For **production** environment:

```hcl
# backend/environments/prod/terraform.tfvars

environment = "prod"
vpc_cidr    = "10.2.0.0/16"

# Custom domain configuration
domain_name = "dashboard.synoptik.com"  # or just "synoptik.com"
```

For **staging**:

```hcl
# backend/environments/staging/terraform.tfvars

environment = "staging"
vpc_cidr    = "10.1.0.0/16"

domain_name = "staging.synoptik.com"
```

For **dev**:

```hcl
# backend/environments/dev/terraform.tfvars

environment = "dev"
vpc_cidr    = "10.0.0.0/16"

domain_name = "dev.synoptik.com"
```

### Step 3: Deploy with Terraform

```bash
cd backend

# Initialize Terraform
terraform init -backend-config=environments/prod/backend.tfvars

# Plan the deployment
terraform plan \
  -var-file=environments/prod/terraform.tfvars \
  -var="project_name=synoptik" \
  -var="aws_region=us-east-1" \
  -var="github_token=$GITHUB_TOKEN" \
  -var="sentry_dsn_frontend=$SENTRY_DSN_FRONTEND" \
  -var="sentry_dsn_backend=$SENTRY_DSN_BACKEND"

# Apply the changes
terraform apply \
  -var-file=environments/prod/terraform.tfvars \
  -var="project_name=synoptik" \
  -var="aws_region=us-east-1" \
  -var="github_token=$GITHUB_TOKEN" \
  -var="sentry_dsn_frontend=$SENTRY_DSN_FRONTEND" \
  -var="sentry_dsn_backend=$SENTRY_DSN_BACKEND"
```

Terraform will:
- ✅ Request an ACM certificate
- ✅ Create DNS validation records in Route53
- ✅ Wait for certificate validation
- ✅ Configure CloudFront with the custom domain
- ✅ Create A and AAAA records pointing to CloudFront

### Step 4: Verify

```bash
# Check certificate status
aws acm list-certificates --region us-east-1

# Test DNS resolution
dig dashboard.synoptik.com
nslookup dashboard.synoptik.com

# Test HTTPS
curl -I https://dashboard.synoptik.com
```

## Option 2: Using Namecheap DNS (Manual Setup)

If you prefer to keep DNS at Namecheap, follow these steps:

### Step 1: Request ACM Certificate Manually

1. Go to AWS Certificate Manager (us-east-1 region)
2. Click **Request a certificate**
3. Choose **Request a public certificate**
4. Enter your domain name: `dashboard.synoptik.com`
5. Choose **DNS validation**
6. Click **Request**

### Step 2: Add DNS Validation Records to Namecheap

1. In ACM, click on your certificate
2. Copy the CNAME record details (Name and Value)
3. Go to Namecheap → Domain List → Manage → Advanced DNS
4. Click **Add New Record**:
   - Type: **CNAME Record**
   - Host: Copy from ACM (e.g., `_abc123.dashboard`)
   - Value: Copy from ACM (e.g., `_xyz456.acm-validations.aws`)
   - TTL: **Automatic**
5. Click **Save**
6. Wait for validation (can take 5-30 minutes)

### Step 3: Update Terraform with Existing Certificate

```hcl
# backend/environments/prod/terraform.tfvars

environment = "prod"
vpc_cidr    = "10.2.0.0/16"

domain_name         = "dashboard.synoptik.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123-def"
```

### Step 4: Deploy with Terraform

```bash
terraform apply -var-file=environments/prod/terraform.tfvars # ... (other vars)
```

### Step 5: Add CNAME Record to Namecheap

After Terraform creates the CloudFront distribution:

1. Get the CloudFront domain name:
   ```bash
   terraform output cloudfront_domain_name
   # Example: d1234abcd.cloudfront.net
   ```

2. Go to Namecheap → Advanced DNS
3. Add a CNAME record:
   - Type: **CNAME Record**
   - Host: `dashboard` (or `@` for root domain)
   - Value: `d1234abcd.cloudfront.net` (from Terraform output)
   - TTL: **Automatic**
4. Click **Save**

## Important Notes

### ACM Certificate Region

- ⚠️ **CloudFront requires certificates in us-east-1 region**
- If your infrastructure is in another region, you must create the certificate in us-east-1

### Root Domain vs Subdomain

- **Subdomain** (recommended): `dashboard.synoptik.com` - Use CNAME record
- **Root domain**: `synoptik.com` - Must use Route53 or ALIAS record (Namecheap doesn't support ALIAS)

### DNS Propagation Time

- Route53 nameserver changes: **24-48 hours**
- CNAME record changes: **5-30 minutes**
- ACM validation: **5-30 minutes**

### SSL/TLS Configuration

- The configuration automatically enforces HTTPS
- TLS 1.2 is the minimum version (modern and secure)
- HTTP requests are automatically redirected to HTTPS

## Testing Your Setup

### 1. Check DNS Resolution

```bash
# Check if domain resolves
nslookup dashboard.synoptik.com

# Should return CloudFront IP addresses
dig dashboard.synoptik.com +short
```

### 2. Test SSL Certificate

```bash
# Check certificate details
openssl s_client -connect dashboard.synoptik.com:443 -servername dashboard.synoptik.com

# Verify HTTPS works
curl -I https://dashboard.synoptik.com
```

### 3. Test in Browser

1. Open `https://dashboard.synoptik.com`
2. Click the padlock icon in the address bar
3. Verify the certificate is issued by Amazon
4. Check that it's valid and trusted

## Troubleshooting

### Certificate Validation Stuck

**Problem**: ACM certificate stuck in "Pending validation"

**Solution**:
```bash
# Check DNS records
dig _abc123.dashboard.synoptik.com CNAME +short

# Verify the CNAME value matches ACM
aws acm describe-certificate --certificate-arn <ARN> --region us-east-1
```

### Domain Not Resolving

**Problem**: `nslookup` returns no results

**Solutions**:
- Wait longer (DNS propagation can take time)
- Check nameservers: `dig synoptik.com NS +short`
- Verify CNAME record is correct in Namecheap

### CloudFront Returns 403/404

**Problem**: Domain resolves but returns error

**Solutions**:
- Deploy your React app to S3: `aws s3 sync ./frontend/dist s3://prod-synoptik-dashboard/`
- Check CloudFront invalidation: `aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"`
- Verify S3 bucket policy allows CloudFront access

### Mixed Content Errors

**Problem**: Browser shows "Not Secure" warning

**Solution**: Ensure all resources (images, CSS, JS) use HTTPS URLs

## GitHub Actions Integration

Update your workflow to pass the domain variables:

```yaml
- name: Terraform Apply
  working-directory: backend
  run: |
    terraform apply \
      -var-file=environments/${{ env.DEPLOY_ENV }}/terraform.tfvars \
      -var="project_name=${{ env.PROJECT_NAME }}" \
      -var="aws_region=${{ secrets.AWS_REGION }}" \
      -var="github_token=${{ secrets.GITHUB_TOKEN_SECRET }}" \
      -var="sentry_dsn_frontend=${{ secrets.SENTRY_DSN_FRONTEND }}" \
      -var="sentry_dsn_backend=${{ secrets.SENTRY_DSN_BACKEND }}" \
      -var="domain_name=${{ secrets.DOMAIN_NAME }}" \
      -var="acm_certificate_arn=${{ secrets.ACM_CERTIFICATE_ARN }}" \
      -auto-approve
```

Add these as GitHub Environment secrets:
- `DOMAIN_NAME` - Your custom domain (e.g., `dashboard.synoptik.com`)
- `ACM_CERTIFICATE_ARN` - Optional, if using existing certificate

## Cost Considerations

- **Route53 Hosted Zone**: $0.50/month
- **ACM Certificate**: Free
- **CloudFront**: Pay-as-you-go (typically $0.085 per GB transferred)
- **Domain Registration**: ~$10-15/year (at Namecheap)

## Security Best Practices

1. ✅ Always use HTTPS (enforced by CloudFront config)
2. ✅ Enable CloudFront access logs
3. ✅ Set up AWS WAF for DDoS protection (optional)
4. ✅ Use Route53 health checks (optional)
5. ✅ Enable CloudFront field-level encryption (optional)

## Next Steps

After your domain is set up:

1. Update your React app's API endpoint to use the custom domain
2. Update CORS settings in API Gateway to allow the custom domain
3. Configure Sentry to use the custom domain
4. Set up monitoring alerts for SSL certificate expiration

## Support

For issues:
- AWS Certificate Manager: Check ACM console for validation status
- Namecheap DNS: Check Advanced DNS tab for record propagation
- CloudFront: Check CloudFront distribution settings and behaviors
