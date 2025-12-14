#!/bin/bash
set -e

# Load project ID
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

PROJECT_ID=${GCP_PROJECT:-$(gcloud config get-value project)}

if [ -z "$PROJECT_ID" ]; then
    echo "Error: PROJECT_ID could not be determined."
    exit 1
fi

echo "🚀 Creating API Key for Project: $PROJECT_ID"

# 1. Enable Generative Language API
echo "Enabling Generative Language API..."
gcloud services enable generativelanguage.googleapis.com apikeys.googleapis.com --project=$PROJECT_ID

# 2. Create API Key
echo "Creating API Key..."
# We attempt to create it. If it exists, this might fail or return an op. We ignore the output/error safely.
gcloud beta services api-keys create \
    --project=$PROJECT_ID \
    --display-name="Gemini Agent Key" \
    --api-target=service=generativelanguage.googleapis.com \
    2>/dev/null || true

# 3. Find the Key Resource Name
echo "Retrieving Key ID..."
KEY_RESOURCE=$(gcloud beta services api-keys list \
    --project=$PROJECT_ID \
    --filter="displayName='Gemini Agent Key'" \
    --format="value(name)" \
    | head -n 1)

if [ -z "$KEY_RESOURCE" ]; then
    echo "Error: Could not find API key with display name 'Gemini Agent Key'."
    exit 1
fi

# 4. Get Key String
KEY_STRING=$(gcloud beta services api-keys get-key-string $KEY_RESOURCE --project=$PROJECT_ID --format="value(keyString)")

echo "✅ API Key Created Successfully!"
echo "API Key: $KEY_STRING"

# 5. Update .env automatically
if [ -f .env ]; then
    if grep -q "GOOGLE_API_KEY=" .env; then
        # Replace existing line
        # Use a temporary file to avoid issues
        sed -i.bak "s/^GOOGLE_API_KEY=.*/GOOGLE_API_KEY=$KEY_STRING/" .env
        rm .env.bak
        echo "Updated .env file with new key."
    else
        echo "GOOGLE_API_KEY=$KEY_STRING" >> .env
        echo "Appended key to .env file."
    fi
else
    echo "No .env file found. Please save this key: $KEY_STRING"
fi
