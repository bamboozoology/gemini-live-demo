#!/bin/bash
set -eo pipefail

# --- Helper Functions ---
function error_handler {
  echo "🚨 Error occurred in script at line: $1"
  echo "❌ Deployment Failed!"
  exit 1
}

function check_var {
  if [ -z "${!1}" ]; then
    echo "🚨 Error: Environment variable $1 is not set."
    exit 1
  fi
}

trap 'error_handler $LINENO' ERR

# --- Load Configuration ---
echo "📂 Loading environment..."
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

check_var "GCP_PROJECT"

# --- Parse Arguments ---
MACHINE_TYPE="c4a-highcpu-1"
while [[ $# -gt 0 ]]; do
  case $1 in
    --micro)
      MACHINE_TYPE="e2-micro"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--micro]"
      exit 1
      ;;
  esac
done

PROJECT_ID=$GCP_PROJECT
ZONE="us-central1-a"
INSTANCE_NAME="gemini-live-agent"
REPO_URL="https://github.com/bamboozoology/gemini-live-demo.git"

# Determine image based on machine type (ARM vs x86)
if [[ "$MACHINE_TYPE" == c4a* || "$MACHINE_TYPE" == t2a* ]]; then
  IMAGE_FAMILY="debian-12-arm64"
  IMAGE_PROJECT="debian-cloud"
  echo "   Using ARM64 image for $MACHINE_TYPE"
else
  IMAGE_FAMILY="debian-12"
  IMAGE_PROJECT="debian-cloud"
  echo "   Using x86_64 image for $MACHINE_TYPE"
fi

# --- 1. Infrastructure Checks ---
echo "🛠️  Checking project configuration for $PROJECT_ID..."
gcloud services enable compute.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID --quiet

# Ensure SSH is allowed
echo "   Ensuring SSH firewall rule..."
gcloud compute firewall-rules create allow-ssh --allow tcp:22 --project=$PROJECT_ID --quiet 2>/dev/null || true

# --- 2. Delete existing instance if exists ---
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID &>/dev/null; then
    echo "   Instance exists. Deleting..."
    gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID --quiet
fi

# --- 3. Create VM ---
echo "🚀 Creating VM ($INSTANCE_NAME - $MACHINE_TYPE)..."
gcloud compute instances create $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --image-family=$IMAGE_FAMILY \
    --image-project=$IMAGE_PROJECT \
    --tags=livekit-agent \
    --service-account=gemini-agent-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform

# Wait for SSH to be ready
echo "⏳ Waiting for SSH to be ready..."
sleep 30

# --- 4. Setup VM via SSH ---
echo "📦 Installing dependencies and starting agent..."
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID --command="
set -e

# Install system dependencies
sudo apt-get update
sudo apt-get install -y git curl python3 python3-pip python3-venv

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH=\"\$HOME/.local/bin:\$PATH\"

# Clone repo
rm -rf ~/gemini-live-demo
git clone $REPO_URL ~/gemini-live-demo
cd ~/gemini-live-demo

# Set GCP_PROJECT env var
export GCP_PROJECT=$PROJECT_ID

# Sync dependencies
~/.local/bin/uv sync

# Run agent in background with nohup
nohup ~/.local/bin/uv run python agent.py start > ~/agent.log 2>&1 &

echo 'Agent started in background. Check ~/agent.log for logs.'
"

# --- 5. Verify ---
echo "🔍 Verifying deployment..."
STATUS=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID --format="value(status)")

if [ "$STATUS" == "RUNNING" ]; then
    echo "✅ Success! Instance '$INSTANCE_NAME' is RUNNING."
    echo "   IP Address: $(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
    echo ""
    echo "   View logs: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='tail -f ~/agent.log'"
    echo "   SSH in:    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
else
    echo "⚠️  Instance created but status is: $STATUS"
    exit 1
fi
