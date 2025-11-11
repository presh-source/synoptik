# GitHub Setup Guide for Synoptik

## Quick Setup

Follow these steps to push your Synoptik project to a private GitHub repository.

### Step 1: Create a Private Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `Synoptik` (or your preferred name)
3. Description: "A comprehensive data platform for GitHub ecosystem analytics"
4. **Select "Private"**
5. **Do NOT initialize with README, .gitignore, or license** (we already have these)
6. Click "Create repository"

### Step 2: Initialize Git and Push

Run these commands in your project directory:

```bash
# Initialize git repository (if not already initialized)
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Synoptik platform with LocalStack support"

# Add your GitHub repository as remote
# Replace YOUR_USERNAME with your GitHub username
git remote add origin https://github.com/YOUR_USERNAME/Synoptik.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Verify

Visit your repository on GitHub to confirm all files were pushed successfully.

## Alternative: Using SSH

If you prefer SSH authentication:

```bash
# Add remote using SSH
git remote add origin git@github.com:YOUR_USERNAME/Synoptik.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## What Gets Pushed

The following will be included in your repository:

✅ **Source Code**
- Dashboard React application
- Terraform infrastructure code
- Lambda functions
- Deployment scripts

✅ **Documentation**
- README.md
- LOCALSTACK_SETUP.md
- DEPLOYMENT.md
- All other .md files

✅ **Configuration**
- docker-compose.localstack.yml
- Terraform configurations
- Package.json files

❌ **Excluded (via .gitignore)**
- node_modules/
- dist/
- localstack-data/
- .env files
- Terraform state files
- IDE settings

## Protecting Sensitive Information

Before pushing, ensure no sensitive data is committed:

```bash
# Check for sensitive files
git status

# Review what will be committed
git diff --cached

# If you find sensitive data, remove it:
git reset HEAD path/to/sensitive/file
```

### Important: Never Commit

- ❌ AWS credentials
- ❌ GitHub tokens
- ❌ .env files with secrets
- ❌ terraform.tfstate files
- ❌ Private keys

These are already in `.gitignore`, but double-check!

## Setting Up GitHub Secrets (for CI/CD)

After pushing, set up GitHub Secrets for automated deployments:

1. Go to your repository on GitHub
2. Click "Settings" → "Secrets and variables" → "Actions"
3. Click "New repository secret"
4. Add these secrets:

```
AWS_ACCESS_KEY_ID          = your_aws_access_key
AWS_SECRET_ACCESS_KEY      = your_aws_secret_key
API_URL                    = your_api_gateway_url
GITHUB_TOKEN              = your_github_personal_access_token
```

## Branch Protection (Recommended)

Protect your main branch:

1. Go to "Settings" → "Branches"
2. Click "Add rule"
3. Branch name pattern: `main`
4. Enable:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging

## Collaborators

To add collaborators to your private repository:

1. Go to "Settings" → "Collaborators"
2. Click "Add people"
3. Enter their GitHub username or email
4. Select permission level (Read, Write, or Admin)

## Repository Settings

Recommended settings for your private repository:

### General
- ✅ Disable "Wikis" (use docs in repo instead)
- ✅ Disable "Projects" (unless you use them)
- ✅ Enable "Issues"
- ✅ Enable "Discussions" (optional)

### Security
- ✅ Enable "Dependency graph"
- ✅ Enable "Dependabot alerts"
- ✅ Enable "Dependabot security updates"

## Useful Git Commands

```bash
# Check repository status
git status

# View commit history
git log --oneline

# Create a new branch
git checkout -b feature/new-feature

# Push new branch
git push -u origin feature/new-feature

# Pull latest changes
git pull origin main

# View remote repositories
git remote -v

# Update remote URL if needed
git remote set-url origin https://github.com/YOUR_USERNAME/Synoptik.git
```

## Troubleshooting

### Authentication Failed

If you get authentication errors:

**For HTTPS:**
```bash
# Use Personal Access Token instead of password
# Generate token at: https://github.com/settings/tokens
# Use token as password when prompted
```

**For SSH:**
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Add public key to GitHub
# Copy key: cat ~/.ssh/id_ed25519.pub
# Add at: https://github.com/settings/keys
```

### Large Files

If you have large files (>100MB):

```bash
# Use Git LFS
git lfs install
git lfs track "*.zip"
git lfs track "*.tar.gz"
git add .gitattributes
git commit -m "Add Git LFS tracking"
```

### Already Initialized Git

If git is already initialized:

```bash
# Check current remote
git remote -v

# If wrong remote, update it
git remote set-url origin https://github.com/YOUR_USERNAME/Synoptik.git

# Or remove and re-add
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/Synoptik.git
```

## Next Steps After Pushing

1. **Add Repository Description**
   - Go to repository settings
   - Add description and topics (tags)

2. **Create README Badge**
   - Add build status badges
   - Add license badge
   - Add version badge

3. **Set Up GitHub Actions**
   - Workflows are already in `.github/workflows/`
   - They'll run automatically on push

4. **Create Issues/Projects**
   - Track features and bugs
   - Plan development roadmap

5. **Write CONTRIBUTING.md**
   - Guidelines for contributors
   - Code style and standards

## Repository Topics (Tags)

Add these topics to your repository for better discoverability:

- `github-api`
- `data-platform`
- `aws`
- `terraform`
- `react`
- `typescript`
- `localstack`
- `serverless`
- `analytics`
- `opensearch`
- `neptune`

## License

Consider adding a license file:

```bash
# Create LICENSE file
# Choose from: MIT, Apache-2.0, GPL-3.0, etc.
# Add at: https://choosealicense.com/
```

## Support

For GitHub-related issues:
- GitHub Docs: https://docs.github.com
- GitHub Support: https://support.github.com
