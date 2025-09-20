# Misinformation Detection & Education App - Deployment Guide

## Overview

This guide walks you through deploying the complete Misinformation Detection & Education App with Google Cloud services backend and Flutter frontend.

## Architecture Summary

- **Frontend**: Flutter mobile app with PWA wrapper
- **Backend**: Python FastAPI on Google Cloud Run
- **Database**: Cloud Firestore + BigQuery for analytics
- **AI/ML**: Vertex AI for claim verification
- **Storage**: Cloud Storage for media files
- **Authentication**: Firebase Auth
- **Monitoring**: Cloud Monitoring & Logging

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **Flutter SDK** 3.0+ installed
3. **Python** 3.9+ installed
4. **Google Cloud CLI** installed and authenticated
5. **Firebase CLI** installed
6. **Git** for version control

## Step 1: Google Cloud Setup

### 1.1 Create Project
```bash
# Create new project
gcloud projects create your-project-id --name="Misinformation Detection App"

# Set as default project
gcloud config set project your-project-id
```

### 1.2 Run Setup Script
```bash
cd backend/deploy
chmod +x setup-gcp.sh
./setup-gcp.sh your-project-id us-central1
```

### 1.3 Enable APIs Manually (if needed)
```bash
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    firestore.googleapis.com \
    aiplatform.googleapis.com \
    vision.googleapis.com \
    translate.googleapis.com
```

## Step 2: Firebase Configuration

### 2.1 Firebase Console Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Enable Authentication:
   - Go to Authentication > Sign-in method
   - Enable Google and Email/Password providers
4. Set up Firestore:
   - Go to Firestore Database
   - Create database in production mode
   - Choose region (same as Cloud Run)

### 2.2 Get Firebase Config
1. Go to Project Settings > General
2. Add a web app
3. Copy config and update `lib/firebase_options.dart`

### 2.3 Download Service Account Key
1. Go to Project Settings > Service accounts
2. Generate new private key
3. Store in Secret Manager:
```bash
gcloud secrets create firebase-service-account-key --data-file=path/to/key.json
```

## Step 3: Backend Deployment

### 3.1 Environment Configuration
```bash
cd backend
cp .env.example .env
# Edit .env with your project-specific values
```

### 3.2 Create Required Secrets
```bash
# JWT Secret
openssl rand -base64 32 | gcloud secrets create jwt-secret-key --data-file=-

# API Keys (replace with actual keys)
echo "your-vertex-ai-key" | gcloud secrets create vertex-ai-api-key --data-file=-
echo "your-vision-api-key" | gcloud secrets create vision-api-key --data-file=-
```

### 3.3 Deploy to Cloud Run
```bash
# Build and deploy
gcloud builds submit --config cloudbuild.yaml

# Or deploy manually
docker build -t gcr.io/your-project-id/misinformation-api .
docker push gcr.io/your-project-id/misinformation-api
gcloud run deploy misinformation-api \
    --image gcr.io/your-project-id/misinformation-api \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated
```

### 3.4 Configure Environment Variables
```bash
gcloud run services update misinformation-api \
    --set-env-vars="GOOGLE_CLOUD_PROJECT=your-project-id" \
    --set-env-vars="ENVIRONMENT=production" \
    --region us-central1
```

## Step 4: Vertex AI Model Setup

### 4.1 Create Model Endpoints
```bash
# Create endpoints for custom models (example)
gcloud ai endpoints create \
    --display-name="claim-detection-endpoint" \
    --region=us-central1

gcloud ai endpoints create \
    --display-name="harm-classification-endpoint" \
    --region=us-central1
```

### 4.2 Deploy Pre-trained Models
For this demo, the backend uses Google's pre-trained models:
- `text-bison@002` for text generation
- `textembedding-gecko@003` for embeddings
- Custom models would need to be trained separately

## Step 5: Frontend Deployment

### 5.1 Update API Endpoint
Edit `lib/services/api_service.dart`:
```dart
static const String _baseUrl = 'https://your-cloud-run-url';
```

### 5.2 Build Flutter App
```bash
# Get dependencies
flutter pub get

# Build APK
flutter build apk --release

# Build for web (PWA)
flutter build web --web-renderer html
```

### 5.3 Deploy Web Version (Optional)
```bash
# Deploy to Firebase Hosting
firebase init hosting
firebase deploy --only hosting
```

## Step 6: Database Setup

### 6.1 Firestore Collections
Create these collections in Firestore:
- `users` - User profiles
- `claims` - Submitted claims
- `verifications` - Verification results
- `education_content` - Learning materials
- `learning_modules` - Structured lessons
- `user_progress` - Learning progress tracking

### 6.2 Security Rules
Update Firestore rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /claims/{claimId} {
      allow read, write: if request.auth != null;
    }
    
    match /education_content/{contentId} {
      allow read: if true; // Public read access
      allow write: if false; // Admin only
    }
  }
}
```

### 6.3 BigQuery Tables
Tables are created automatically by the setup script, but you can create them manually:
```sql
CREATE TABLE `your-project-id.misinformation_analytics.claims_analysis` (
  claim_id STRING,
  user_id STRING,
  submitted_at TIMESTAMP,
  text STRING,
  language STRING,
  verdict STRING,
  confidence_score FLOAT64,
  harm_level STRING,
  category STRING,
  source_domain STRING,
  user_location STRING,
  keywords STRING
);
```

## Step 7: Testing

### 7.1 API Testing
```bash
# Test health endpoint
curl https://your-cloud-run-url/api/health

# Test with authentication
curl -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
     https://your-cloud-run-url/api/users/profile
```

### 7.2 Flutter Testing
```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Step 8: Monitoring & Security

### 8.1 Enable Cloud Monitoring
```bash
# Create monitoring workspace (done automatically with setup script)
# Set up custom dashboards in Cloud Console
```

### 8.2 Cloud Armor Security
```bash
# Apply security policy to Cloud Run
gcloud compute backend-services update your-backend-service \
    --security-policy=misinformation-api-policy \
    --global
```

### 8.3 Rate Limiting
Rate limiting is configured in the security policy created by the setup script.

## Step 9: CI/CD Setup

### 9.1 Cloud Build Trigger
```bash
# Connect GitHub repository
gcloud builds triggers create github \
    --repo-name="your-repo" \
    --repo-owner="your-username" \
    --branch-pattern="^main$" \
    --build-config="backend/cloudbuild.yaml"
```

### 9.2 Automated Testing
The `cloudbuild.yaml` includes automated testing steps.

## Configuration Files Overview

```
misinformation_detector_app/
├── backend/
│   ├── main.py                 # FastAPI application
│   ├── requirements.txt        # Python dependencies
│   ├── Dockerfile             # Container configuration
│   ├── cloudbuild.yaml        # CI/CD configuration
│   ├── .env.example          # Environment template
│   ├── routers/              # API endpoints
│   ├── services/             # AI/ML services
│   └── deploy/               # Deployment scripts
├── lib/
│   ├── services/
│   │   └── api_service.dart  # Flutter API client
│   └── firebase_options.dart # Firebase configuration
└── DEPLOYMENT_GUIDE.md       # This file
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Ensure Firebase service account key is in Secret Manager
   - Verify IAM roles are correctly assigned

2. **API Timeout Errors**
   - Increase Cloud Run timeout settings
   - Optimize model inference time

3. **Firestore Permission Errors**
   - Check security rules
   - Verify user authentication

4. **Vertex AI Errors**
   - Ensure APIs are enabled
   - Check service account permissions

### Logs and Debugging

```bash
# View Cloud Run logs
gcloud logs read --service=misinformation-api --limit=100

# View Cloud Build logs
gcloud builds log BUILD_ID

# Flutter debugging
flutter logs
```

## Cost Optimization

1. **Cloud Run**: Use minimum instances = 0 for cost savings
2. **BigQuery**: Use partitioned tables and optimize queries
3. **Cloud Storage**: Use lifecycle policies for old images
4. **Vertex AI**: Use batch prediction for non-real-time processing

## Security Considerations

1. **API Keys**: Always use Secret Manager for sensitive data
2. **CORS**: Restrict origins to your domain
3. **Rate Limiting**: Implement proper rate limiting
4. **Input Validation**: Validate all user inputs
5. **Firestore Rules**: Use proper security rules

## Scaling Considerations

1. **Cloud Run**: Auto-scales based on traffic
2. **Firestore**: Automatically scales, but optimize queries
3. **BigQuery**: Use clustering and partitioning
4. **Vertex AI**: Consider using multiple model versions

## Support

- Review Google Cloud documentation
- Check Firebase documentation
- File issues in the project repository
- Monitor Cloud Monitoring dashboards

---

**Note**: Replace all placeholder values (your-project-id, your-repo, etc.) with actual values for your deployment.