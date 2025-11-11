# Push Synoptik to GitHub - Quick Guide

## Option 1: Automated Script (Recommended)

Run the automated script that will guide you through the process:

```bash
./push-to-github.sh
```

The script will:
1. ✅ Check if git is installed
2. ✅ Ask for your GitHub username
3. ✅ Ask for repository name (default: Synoptik)
4. ✅ Check for sensitive files
5. ✅ Initialize git repository
6. ✅ Add all files
7. ✅ Create initial commit
8. ✅ Add GitHub remote
9. ✅ Push to GitHub

## Option 2: Manual Steps

### Step 1: Create Private Repository on GitHub

1. Go to https://github.com/new
2. Repository name: **Synoptik**
3. Description: "A comprehensive data platform for GitHub ecosystem analytics"
4. **Select "Private"** ⚠️
5. **Do NOT** initialize with README, .gitignore, or license
6. Click "Create repository"

### Step 2: Push Your Code

```bash
# Initialize git
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Synoptik platform with LocalStack support"

# Add your GitHub repository as remote
# Replace YOUR_USERNAME with your actual GitHub username
git remote add origin https://github.com/YOUR_USERNAME/Synoptik.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Enter Credentials

When prompted for credentials:
- **Username**: Your GitHub username
- **Password**: Use a **Personal Access Token** (NOT your GitHub password)

#### Generate Personal Access Token:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name: "Synoptik Repository Access"
4. Expiration: Choose duration (90 days recommended)
5. Select scopes:
   - ✅ `repo` (Full control of private repositories)
6. Click "Generate token"
7. **Copy the token** (you won't see it again!)
8. Use this token as your password when pushing

## What Gets Pushed

### ✅ Included
- Dashboard React application
- Terraform infrastructure code
- LocalStack configuration
- Deployment scripts
- Documentation files
- Configuration files

### ❌ Excluded (via .gitignore)
- `node_modules/`
- `dist/`
- `localstack-data/`
- `.env` files
- `terraform.tfstate` files
- IDE settings (`.vscode/`, `.idea/`)
- OS files (`.DS_Store`)

## Verify Push

After pushing, verify on GitHub:

1. Go to https://github.com/YOUR_USERNAME/Synoptik
2. Check that files are there
3. Verify repository is **Private** (lock icon)
4. Check that no sensitive files were committed

## Troubleshooting

### Authentication Failed

**Problem**: "Authentication failed" error

**Solution**: Use Personal Access Token instead of password
```bash
# Generate token at: https://github.com/settings/tokens
# Use token as password when prompted
```

### Repository Not Empty

**Problem**: "Updates were rejected because the remote contains work"

**Solution**: Make sure you created an empty repository (no README, .gitignore, or license)

### Permission Denied

**Problem**: "Permission denied (publickey)"

**Solution**: Use HTTPS instead of SSH, or set up SSH keys
```bash
# Use HTTPS URL
git remote set-url origin https://github.com/YOUR_USERNAME/Synoptik.git
```

### Large Files

**Problem**: "File is too large" error

**Solution**: Check .gitignore and ensure large files are excluded
```bash
# Check what's being committed
git status

# If large files are staged, unstage them
git reset HEAD path/to/large/file

# Add to .gitignore
echo "path/to/large/file" >> .gitignore
```

## After Pushing

### 1. Add Repository Description

On GitHub repository page:
- Click "⚙️ Settings"
- Add description: "A comprehensive data platform for GitHub ecosystem analytics"
- Add website (if applicable)
- Add topics: `github-api`, `data-platform`, `aws`, `terraform`, `react`, `localstack`

### 2. Set Up GitHub Secrets (for CI/CD)

Go to Settings → Secrets and variables → Actions:

```
AWS_ACCESS_KEY_ID          = your_aws_access_key
AWS_SECRET_ACCESS_KEY      = your_aws_secret_key
API_URL                    = your_api_gateway_url
GITHUB_TOKEN              = your_github_personal_access_token
```

### 3. Enable Branch Protection

Go to Settings → Branches → Add rule:
- Branch name pattern: `main`
- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging

### 4. Invite Collaborators (Optional)

Go to Settings → Collaborators:
- Click "Add people"
- Enter GitHub username or email
- Select permission level

## Useful Commands

```bash
# Check repository status
git status

# View commit history
git log --oneline

# View remote URL
git remote -v

# Pull latest changes
git pull origin main

# Create new branch
git checkout -b feature/new-feature

# Push new branch
git push -u origin feature/new-feature
```

## Security Checklist

Before pushing, ensure:

- ✅ No AWS credentials in code
- ✅ No GitHub tokens in code
- ✅ No `.env` files committed
- ✅ No `terraform.tfstate` files
- ✅ No private keys
- ✅ Repository is set to **Private**
- ✅ `.gitignore` is properly configured

## Need Help?

- See `GITHUB_SETUP.md` for detailed instructions
- GitHub Docs: https://docs.github.com
- Git Docs: https://git-scm.com/doc

## Quick Reference

```bash
# Automated push (recommended)
./push-to-github.sh

# Manual push
git init
git add .
git commit -m "Initial commit: Synoptik platform"
git remote add origin https://github.com/YOUR_USERNAME/Synoptik.git
git branch -M main
git push -u origin main

# Check status
git status

# View remote
git remote -v
```

---

**Remember**: Always use a **Personal Access Token** as your password, not your GitHub password!

Generate token at: https://github.com/settings/tokens
