#!/bin/bash
set -e

# Usage: ./setup_gcp.sh [PROJECT_ID]
if [ -z "$1" ]; then
    PROJECT_ID=$(gcloud config get-value project)
    if [ -z "$PROJECT_ID" ]; then
        echo "Error: No project ID provided and none set in gcloud config."
        echo "Usage: ./setup_gcp.sh <PROJECT_ID>"
        exit 1
    fi
else
    PROJECT_ID=$1
fi

echo "🚀 Setting up GCP Project: $PROJECT_ID"
echo "---------------------------------------"

# 1. Enable APIs
echo "Enable APIs (Compute, Artifact Registry, Cloud Build)..."
gcloud services enable compute.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com --project=$PROJECT_ID

# 2. Create Artifact Registry Repository
REPO_NAME="gemini-agent-repo"
LOCATION="us-central1"

echo "Creating Artifact Registry repo: $REPO_NAME..."
if ! gcloud artifacts repositories describe $REPO_NAME --location=$LOCATION --project=$PROJECT_ID &>/dev/null; then
    gcloud artifacts repositories create $REPO_NAME \
        --repository-format=docker \
        --location=$LOCATION \
        --description="Docker repository for Gemini Live Agent" \
        --project=$PROJECT_ID
else
    echo "  -> Repo $REPO_NAME already exists. Skipping."
fi

# 3. Configure Docker Auth (Local)
echo "Configuring local Docker auth for $LOCATION-docker.pkg.dev..."
gcloud auth configure-docker $LOCATION-docker.pkg.dev --quiet

# 4. Create Service Account
SA_NAME="gemini-agent-sa"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

echo "Creating Service Account: $SA_NAME..."
if ! gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
    gcloud iam service-accounts create $SA_NAME \
        --display-name="Gemini Agent Service Account" \
        --project=$PROJECT_ID
else
    echo "  -> Service Account $SA_NAME already exists. Skipping."
fi

# 5. Grant Permissions (Pull Images)
echo "Granting Artifact Registry Reader permission to $SA_EMAIL..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/artifactregistry.reader" \
    --condition=None \
    --quiet > /dev/null

echo "---------------------------------------"
echo "✅ GCP Setup Complete for project: $PROJECT_ID"
echo "Next step: Run ./deploy_gce.sh"
