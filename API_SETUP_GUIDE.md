# Google Cloud API Setup Guide

## Required APIs to Enable

For the Misinformation Detection App to work properly with the provided Gemini API key, you need to enable the following Google Cloud APIs:

### 1. Core AI/ML APIs

#### **Generative AI (Gemini) API** ✅
- **Status**: Configure with your API key in `.env` file
- **Usage**: Claim verification, text generation, translation, harm detection
- **Enable at**: https://makersuite.google.com/app/apikey

#### **Cloud Vision API**
- **Purpose**: OCR text extraction from images
- **Enable Command**: 
```bash
gcloud services enable vision.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/vision.googleapis.com

#### **Cloud Translation API**
- **Purpose**: Multi-language support (Hindi, Marathi, Tamil, Bengali, etc.)
- **Enable Command**: 
```bash
gcloud services enable translate.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/translate.googleapis.com

#### **Cloud Natural Language API**
- **Purpose**: Entity extraction, sentiment analysis
- **Enable Command**: 
```bash
gcloud services enable language.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/language.googleapis.com

### 2. Storage & Database APIs

#### **Cloud Firestore API**
- **Purpose**: User profiles, claims, verification history storage
- **Enable Command**: 
```bash
gcloud services enable firestore.googleapis.com
```
- **Console**: https://console.cloud.google.com/firestore

#### **Cloud Storage API**
- **Purpose**: Store uploaded images and media files
- **Enable Command**: 
```bash
gcloud services enable storage-component.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/storage-component.googleapis.com

#### **BigQuery API**
- **Purpose**: Analytics and trend tracking
- **Enable Command**: 
```bash
gcloud services enable bigquery.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/bigquery.googleapis.com

### 3. Infrastructure APIs

#### **Cloud Run API**
- **Purpose**: Serverless backend deployment
- **Enable Command**: 
```bash
gcloud services enable run.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/run.googleapis.com

#### **Cloud Build API**
- **Purpose**: CI/CD pipeline
- **Enable Command**: 
```bash
gcloud services enable cloudbuild.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com

#### **Pub/Sub API**
- **Purpose**: Asynchronous message processing
- **Enable Command**: 
```bash
gcloud services enable pubsub.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/pubsub.googleapis.com

#### **Cloud Tasks API**
- **Purpose**: Task queue management
- **Enable Command**: 
```bash
gcloud services enable cloudtasks.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/cloudtasks.googleapis.com

### 4. Security & Monitoring APIs

#### **Secret Manager API**
- **Purpose**: Secure storage of API keys and credentials
- **Enable Command**: 
```bash
gcloud services enable secretmanager.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/secretmanager.googleapis.com

#### **Cloud Logging API**
- **Purpose**: Application logging
- **Enable Command**: 
```bash
gcloud services enable logging.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/logging.googleapis.com

#### **Cloud Monitoring API**
- **Purpose**: Performance monitoring and alerts
- **Enable Command**: 
```bash
gcloud services enable monitoring.googleapis.com
```
- **Console**: https://console.cloud.google.com/apis/library/monitoring.googleapis.com

### 5. Firebase APIs

#### **Firebase Authentication**
- **Purpose**: User authentication (Google + Email/Password)
- **Setup**: Configure in Firebase Console
- **URL**: https://console.firebase.google.com/

#### **Firebase Cloud Storage**
- **Purpose**: Media file uploads from Flutter app
- **Setup**: Automatic with Firebase project

## Quick Setup Script

Run this script to enable all required APIs at once:

```bash
#!/bin/bash

# Set your project ID
PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable all required APIs
gcloud services enable \
    vision.googleapis.com \
    translate.googleapis.com \
    language.googleapis.com \
    firestore.googleapis.com \
    storage-component.googleapis.com \
    bigquery.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    pubsub.googleapis.com \
    cloudtasks.googleapis.com \
    secretmanager.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com

echo "All APIs enabled successfully!"
```

## API Key Configuration

### Gemini API Key Usage
The Gemini API key (stored in `GEMINI_API_KEY` environment variable) is configured for:

1. **Generative Language API** - Text generation and analysis
2. **Safety Settings** - Content moderation
3. **Multi-language Support** - Translation capabilities

### API Key Restrictions (Recommended for Production)

1. **Application Restrictions**:
   - HTTP referrers for web apps
   - IP addresses for server applications
   - Android/iOS apps for mobile

2. **API Restrictions**:
   - Restrict to only the APIs your application uses
   - Set quotas and rate limits

3. **Configure in Console**:
   - Go to: https://console.cloud.google.com/apis/credentials
   - Click on your API key
   - Set restrictions

## Testing the APIs

### Test Gemini API Integration
```bash
cd backend
python test_gemini.py
```

### Test Other APIs
```bash
# Test Vision API
curl -X POST \
  "https://vision.googleapis.com/v1/images:annotate?key=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "requests": [{
      "image": {
        "source": {
          "imageUri": "gs://your-bucket/image.jpg"
        }
      },
      "features": [{
        "type": "TEXT_DETECTION"
      }]
    }]
  }'

# Test Translation API
curl -X POST \
  "https://translation.googleapis.com/language/translate/v2?key=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "q": "Hello world",
    "source": "en",
    "target": "hi"
  }'
```

## Billing Considerations

### Free Tier Limits (as of 2024)
- **Gemini API**: 60 requests per minute (free tier)
- **Cloud Vision**: 1000 units/month free
- **Translation**: $20 per million characters
- **Natural Language**: 5000 units/month free
- **Firestore**: 1GB storage, 50K reads/day free
- **Cloud Run**: 2 million requests/month free

### Cost Optimization Tips
1. Implement caching for repeated queries
2. Use batch processing for non-urgent tasks
3. Store analysis results to avoid reprocessing
4. Set budget alerts in Google Cloud Console

## Next Steps

1. **Create a Google Cloud Project**:
   ```bash
   gcloud projects create misinformation-detector-app
   gcloud config set project misinformation-detector-app
   ```

2. **Enable Billing**:
   - Required for some APIs
   - Set budget alerts
   - URL: https://console.cloud.google.com/billing

3. **Install Dependencies**:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

4. **Run Local Tests**:
   ```bash
   python test_gemini.py
   ```

5. **Deploy to Cloud Run**:
   ```bash
   gcloud builds submit --config cloudbuild.yaml
   ```

## Troubleshooting

### Common Issues

1. **"API not enabled" Error**:
   - Enable the specific API in Cloud Console
   - Wait 1-2 minutes for propagation

2. **"Quota exceeded" Error**:
   - Check quotas in Cloud Console
   - Implement rate limiting in application

3. **"Invalid API key" Error**:
   - Verify key is correct in .env file
   - Check key restrictions in Console

4. **"Permission denied" Error**:
   - Verify IAM roles are correctly set
   - Check service account permissions

## Support Resources

- **Gemini AI Documentation**: https://ai.google.dev/docs
- **Google Cloud Vision**: https://cloud.google.com/vision/docs
- **Cloud Translation**: https://cloud.google.com/translate/docs
- **Firebase Documentation**: https://firebase.google.com/docs
- **Stack Overflow**: Tag with `google-cloud-platform`

---

**Note**: Replace `your-project-id` with your actual Google Cloud project ID throughout this guide.