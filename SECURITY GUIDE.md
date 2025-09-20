# Security Best Practices Guide

## 🔐 API Key Security

### ❌ NEVER DO THIS
```python
# WRONG - Never hardcode API keys
GEMINI_API_KEY = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"  # DON'T DO THIS!
```

### ✅ ALWAYS DO THIS
```python
# CORRECT - Load from environment variables
import os
from dotenv import load_dotenv

load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
```

## 📋 Quick Security Setup

### 1. Create and Configure .env File
```bash
# Run the secure setup script
cd backend
python setup_env.py

# Or manually create .env file
cp .env.example .env
# Then edit .env with your actual API key
```

### 2. Update .gitignore
```bash
# Ensure .env is never committed
echo ".env" >> ../.gitignore
echo ".env.local" >> ../.gitignore
echo ".env.*.local" >> ../.gitignore
```

### 3. Store API Key Securely
```bash
# Option 1: Environment Variable (Development)
export GEMINI_API_KEY="your-api-key-here"

# Option 2: .env File (Development)
echo "GEMINI_API_KEY=your-api-key-here" > .env

# Option 3: Google Secret Manager (Production)
echo -n "your-api-key-here" | gcloud secrets create gemini-api-key --data-file=-
```

## 🛡️ Security Layers

### 1. Development Environment
```python
# .env file (NEVER commit to git)
GEMINI_API_KEY=your-actual-api-key
ENVIRONMENT=development
```

### 2. Staging Environment
```python
# Use environment variables from CI/CD
# Set in GitHub Actions, GitLab CI, etc.
GEMINI_API_KEY=${{ secrets.GEMINI_API_KEY }}
```

### 3. Production Environment
```python
# Use Google Secret Manager
from google.cloud import secretmanager

def get_secret(secret_id):
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode('UTF-8')

GEMINI_API_KEY = get_secret("gemini-api-key")
```

## 🔒 API Key Restrictions

### Configure in Google Cloud Console

1. **Go to API Credentials**
   ```
   https://console.cloud.google.com/apis/credentials
   ```

2. **Set Application Restrictions**
   - **For Backend (Cloud Run)**:
     - IP addresses: Add Cloud Run service IPs
   - **For Mobile Apps**:
     - Android apps: Add package name & SHA-1
     - iOS apps: Add bundle ID
   - **For Web Apps**:
     - HTTP referrers: Add your domains

3. **Set API Restrictions**
   - Restrict to only APIs you use:
     - ✅ Generative Language API
     - ✅ Cloud Vision API (if using)
     - ✅ Translation API (if using)
   - Remove access to all other APIs

4. **Set Quotas**
   ```
   Requests per minute: 60
   Requests per day: 10000
   ```

## 🚨 Security Checklist

### Before Development
- [ ] Create `.env` file from `.env.example`
- [ ] Add `.env` to `.gitignore`
- [ ] Store API key in `.env`
- [ ] Test with `python test_gemini.py`

### Before Committing Code
- [ ] Check no API keys in code: `grep -r "AIza" .`
- [ ] Verify `.env` is in `.gitignore`
- [ ] Review all changes for secrets
- [ ] Use `git status` to ensure `.env` isn't staged

### Before Deployment
- [ ] Move API keys to Secret Manager
- [ ] Set API key restrictions in Console
- [ ] Enable API quotas and monitoring
- [ ] Configure CORS properly
- [ ] Enable Cloud Armor for DDoS protection

## 🔍 Detecting Exposed Keys

### Check for Exposed Keys in Git History
```bash
# Search entire git history for API keys
git log -p | grep -E "AIza[A-Za-z0-9_-]{35}"

# If found, remove from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all
```

### Scan for Secrets
```bash
# Install and use truffleHog
pip install truffleHog3
trufflehog3 --regex --entropy=False .

# Or use git-secrets
brew install git-secrets  # macOS
git secrets --install
git secrets --register-aws  # Add patterns
git secrets --scan
```

## 🔄 Rotating Compromised Keys

### If a Key is Exposed:

1. **Immediately Revoke the Key**
   ```bash
   # Go to Google Cloud Console
   # APIs & Services > Credentials
   # Delete the compromised key
   ```

2. **Generate New Key**
   ```bash
   # Create new API key in Console
   # Update all environments
   ```

3. **Update All Services**
   ```python
   # Update .env file
   GEMINI_API_KEY=new-api-key-here
   
   # Update Secret Manager
   echo -n "new-api-key" | gcloud secrets versions add gemini-api-key --data-file=-
   ```

4. **Monitor for Abuse**
   - Check API usage metrics
   - Review logs for suspicious activity
   - Set up alerts for unusual patterns

## 🏭 Production Security

### Docker Security
```dockerfile
# Don't include .env in Docker image
# .dockerignore
.env
.env.*
*.key
*.pem
```

### Cloud Run Security
```yaml
# cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        # Get secret from Secret Manager
        export GEMINI_API_KEY=$(gcloud secrets versions access latest --secret=gemini-api-key)
```

### Environment Variables in Cloud Run
```bash
# Set from Secret Manager
gcloud run services update misinformation-api \
  --update-secrets=GEMINI_API_KEY=gemini-api-key:latest
```

## 🔧 Security Tools

### 1. Environment Management
```bash
# python-dotenv for .env files
pip install python-dotenv

# direnv for shell environments
brew install direnv  # macOS
apt-get install direnv  # Linux
```

### 2. Secret Scanning
```bash
# Pre-commit hooks
pip install pre-commit
cat > .pre-commit-config.yaml << EOF
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
EOF
pre-commit install
```

### 3. Monitoring
```python
# Log API key usage (never log the key itself!)
import hashlib
import logging

def log_api_usage(api_key):
    # Only log hash of the key, never the actual key
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()[:8]
    logging.info(f"API call made with key hash: {key_hash}")
```

## 📚 Additional Resources

- [Google Cloud Secret Manager](https://cloud.google.com/secret-manager/docs)
- [API Key Best Practices](https://cloud.google.com/docs/authentication/api-keys)
- [OWASP API Security](https://owasp.org/www-project-api-security/)
- [12 Factor App - Config](https://12factor.net/config)

## ⚠️ Emergency Contacts

If you suspect a security breach:

1. **Revoke all API keys immediately**
2. **Contact Google Cloud Support**
3. **Review audit logs**
4. **Notify your security team**

---

**Remember**: Security is not a one-time setup but an ongoing process. Regular audits and updates are essential for maintaining a secure application.