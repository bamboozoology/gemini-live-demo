# Google Cloud Platform (GCP) Setup Guide

This guide details the steps to prepare GCP for deploying the LiveKit Agent docker container.

## Prerequisites
- A Google Cloud Project.
- The `gcloud` CLI installed and authenticated (`gcloud auth login`).

## 1. Enable APIs
Enable the necessary APIs for Compute Engine and Artifact Registry.
```bash
gcloud services enable compute.googleapis.com artifactregistry.googleapis.com
```

## 2. Artifact Registry
Create a repository to store the Agent's Docker images.

1.  **Create Repository**:
    ```bash
    gcloud artifacts repositories create gemini-agent-repo \
        --repository-format=docker \
        --location=us-central1 \
        --description="Docker repository for Gemini Live Agent"
    ```
2.  **Configure Docker Auth**:
    ```bash
    gcloud auth configure-docker us-central1-docker.pkg.dev
    ```

## 3. Service Account (for VM)
Create a Service Account (SA) that the VM will use to pull images and run.

1.  **Create SA**:
    ```bash
    gcloud iam service-accounts create gemini-agent-sa \
        --display-name="Gemini Agent Service Account"
    ```
2.  **Grant Permissions** (Allow it to pull images):
    ```bash
    gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
        --member="serviceAccount:gemini-agent-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/artifactregistry.reader"
    ```
    *Replace `YOUR_PROJECT_ID` with your actual GCP project ID.*

## 4. Deploy Compute Engine VM
You will use the provided `deploy_gce.sh` script to launch the VM. The script automates the following manual steps:

1.  **Image**: Uses `cos-stable` (Container Optimized OS).
2.  **Startup Script**: A script injected into the VM that:
    - Authenticates to the Registry.
    - Runs `docker run` with your `.env` variables.
3.  **Firewall**: The agent makes **outbound** connections to LiveKit Cloud. Standard outbound traffic is allowed by default. No special **inbound** ports need to be opened unless you add a health-check server.

## 5. Deployment command
Once your code is ready and image built, you will run:
```bash
./deploy_gce.sh
```
*(This script will be generated in the Code Implementation phase)*
