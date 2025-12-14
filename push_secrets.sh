#!/bin/bash
set -e

# Load project ID
if [ -f .env ]; then
  # Load without exporting to avoid polluting shell, but we need them for the loop
  # We'll parse the file directly to avoid env var issues
  :
fi

PROJECT_ID=${GCP_PROJECT:-$(gcloud config get-value project)}

echo "🚀 Push Secrets to Secret Manager for Project: $PROJECT_ID"
echo "Enabling Secret Manager API..."
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID

echo "GRANTING permissions to Service Account..."
SA_EMAIL="gemini-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor" \
    --condition=None --quiet > /dev/null

echo "Parsing .env file..."
while read -r line || [ -n "$line" ]; do
  # Trim whitespace
  line=$(echo "$line" | xargs)

  # Skip comments/empty
  [[ $line =~ ^#.* ]] && continue
  [[ -z $line ]] && continue

  # Remove export
  line="${line#export }"

  if [[ "$line" == *"="* ]]; then
      key="${line%%=*}"
      value="${line#*=}"
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)

      # Skip non-secret-ish things if needed, but for now push all
      # Maybe skip HOST/PORT etc if they are config not secret, but user said "pull from secrets"

      echo "Processing $key..."

      # Create secret (ignore if exists)
      gcloud secrets create $key --project=$PROJECT_ID --replication-policy="automatic" 2>/dev/null || true

      # Add version
      echo -n "$value" | gcloud secrets versions add $key --data-file=- --project=$PROJECT_ID >/dev/null
      echo "  -> Updated $key"
  fi
done < .env

echo "✅ Secrets Pushed Successfully!"
