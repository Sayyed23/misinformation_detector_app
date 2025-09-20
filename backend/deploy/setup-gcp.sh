#!/bin/bash

# Setup script for Google Cloud Platform resources
# Run this script to set up the infrastructure for Misinformation Detection App

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"your-project-id"}
REGION=${2:-"us-central1"}
ZONE=${3:-"us-central1-a"}

echo -e "${GREEN}Starting setup for Misinformation Detection App${NC}"
echo -e "${YELLOW}Project ID: $PROJECT_ID${NC}"
echo -e "${YELLOW}Region: $REGION${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}Setting project to $PROJECT_ID${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}Enabling required Google Cloud APIs...${NC}"
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    firestore.googleapis.com \
    storage-component.googleapis.com \
    vision.googleapis.com \
    documentai.googleapis.com \
    translate.googleapis.com \
    language.googleapis.com \
    aiplatform.googleapis.com \
    bigquery.googleapis.com \
    pubsub.googleapis.com \
    cloudtasks.googleapis.com \
    secretmanager.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com

# Create Firestore database
echo -e "${YELLOW}Setting up Firestore database...${NC}"
gcloud firestore databases create --location=$REGION || true

# Create Cloud Storage bucket
echo -e "${YELLOW}Creating Cloud Storage bucket...${NC}"
gsutil mb -l $REGION gs://$PROJECT_ID-misinformation-detection || true

# Set bucket permissions
gsutil iam ch allUsers:objectViewer gs://$PROJECT_ID-misinformation-detection || true

# Create BigQuery dataset
echo -e "${YELLOW}Creating BigQuery dataset...${NC}"
bq mk --location=$REGION misinformation_analytics || true

# Create BigQuery tables
echo -e "${YELLOW}Creating BigQuery tables...${NC}"
bq mk --table \
    $PROJECT_ID:misinformation_analytics.claims_analysis \
    claim_id:STRING,user_id:STRING,submitted_at:TIMESTAMP,text:STRING,language:STRING,verdict:STRING,confidence_score:FLOAT,harm_level:STRING,category:STRING,source_domain:STRING,user_location:STRING,keywords:STRING || true

bq mk --table \
    $PROJECT_ID:misinformation_analytics.user_interactions \
    user_id:STRING,claim_id:STRING,action:STRING,timestamp:TIMESTAMP,device_info:STRING,location:STRING || true

# Create Pub/Sub topics
echo -e "${YELLOW}Creating Pub/Sub topics...${NC}"
gcloud pubsub topics create claim-processing || true
gcloud pubsub topics create harm-alerts || true
gcloud pubsub topics create user-analytics || true

# Create Pub/Sub subscriptions
echo -e "${YELLOW}Creating Pub/Sub subscriptions...${NC}"
gcloud pubsub subscriptions create claim-processing-worker \
    --topic=claim-processing || true

gcloud pubsub subscriptions create harm-alerts-handler \
    --topic=harm-alerts || true

# Create Cloud Tasks queue
echo -e "${YELLOW}Creating Cloud Tasks queue...${NC}"
gcloud tasks queues create misinformation-processing \
    --location=$REGION || true

# Create service accounts
echo -e "${YELLOW}Creating service accounts...${NC}"

# Backend service account
gcloud iam service-accounts create misinformation-backend \
    --display-name="Misinformation Detection Backend" || true

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/firestore.user"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/pubsub.publisher"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/pubsub.subscriber"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudtranslate.user"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/documentai.apiUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:misinformation-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Create secrets in Secret Manager
echo -e "${YELLOW}Creating secrets in Secret Manager...${NC}"

# Create placeholder secrets (you'll need to update these with real values)
echo "your-jwt-secret-key" | gcloud secrets create jwt-secret-key --data-file=- || true
echo "your-api-key" | gcloud secrets create vertex-ai-api-key --data-file=- || true
echo "your-vision-api-key" | gcloud secrets create vision-api-key --data-file=- || true

# Set up Firebase project (requires manual setup)
echo -e "${YELLOW}Firebase setup required:${NC}"
echo "1. Go to https://console.firebase.google.com/"
echo "2. Select your project: $PROJECT_ID"
echo "3. Enable Authentication with Google and Email/Password"
echo "4. Set up Firestore in production mode"
echo "5. Configure Storage rules"
echo "6. Download service account key and add to Secret Manager"

# Set up Cloud Armor security policy
echo -e "${YELLOW}Setting up Cloud Armor security policy...${NC}"
gcloud compute security-policies create misinformation-api-policy \
    --description "Security policy for Misinformation Detection API" || true

# Add rate limiting rule
gcloud compute security-policies rules create 1000 \
    --security-policy misinformation-api-policy \
    --expression "true" \
    --action "rate-based-ban" \
    --rate-limit-threshold-count 100 \
    --rate-limit-threshold-interval-sec 60 \
    --ban-duration-sec 300 \
    --conform-action allow \
    --exceed-action deny-429 || true

# Set up Vertex AI Model Registry (requires manual model deployment)
echo -e "${YELLOW}Vertex AI setup required:${NC}"
echo "1. Train or import your custom models for:"
echo "   - Claim detection"
echo "   - Claim verification"
echo "   - Harm classification"
echo "2. Deploy models to Vertex AI endpoints"
echo "3. Update environment variables with endpoint IDs"

# Set up Cloud Monitoring alerts
echo -e "${YELLOW}Setting up monitoring alerts...${NC}"

# High error rate alert
gcloud alpha monitoring policies create \
    --policy-from-file=monitoring/high-error-rate-policy.yaml || true

# High latency alert  
gcloud alpha monitoring policies create \
    --policy-from-file=monitoring/high-latency-policy.yaml || true

# Create Cloud Build trigger
echo -e "${YELLOW}Setting up Cloud Build trigger...${NC}"
gcloud builds triggers create github \
    --repo-name="your-repo-name" \
    --repo-owner="your-github-username" \
    --branch-pattern="^main$" \
    --build-config="backend/cloudbuild.yaml" || true

echo -e "${GREEN}GCP setup completed!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update .env file with your project-specific values"
echo "2. Set up Firebase Authentication and Firestore"
echo "3. Train and deploy Vertex AI models"
echo "4. Configure external API keys in Secret Manager"
echo "5. Test the deployment with: gcloud builds submit --config backend/cloudbuild.yaml"

echo -e "${GREEN}Setup script completed successfully!${NC}"