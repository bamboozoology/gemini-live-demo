# Gemini Live Demo

A voice AI assistant powered by the **Gemini Live API** and **LiveKit Agents Framework**.

When you call the configured phone number, the agent will answer and you can have a natural voice conversation with Gemini.

## Prerequisites

- **GCP Project** with billing enabled
- **LiveKit Cloud** account with a phone number
- Python 3.13+

## Quick Start

```bash
# 1. Clone and enter directory
git clone https://github.com/bamboozoology/gemini-live-demo.git
cd gemini-live-demo

# 2. Set up environment
cp .env.example .env
# Edit .env with your credentials

# 3. Install dependencies
uv sync

# 4. Deploy
./deploy_gce.sh
```

---

## Developing

### Local Setup

```bash
# Install dependencies
uv sync

# Run agent locally
uv run python agent.py dev
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GCP_PROJECT` | Your GCP project ID |
| `LIVEKIT_URL` | LiveKit Cloud URL (e.g., `wss://xxx.livekit.cloud`) |
| `LIVEKIT_API_KEY` | LiveKit API key |
| `LIVEKIT_API_SECRET` | LiveKit API secret |
| `GOOGLE_API_KEY` | Google AI API key for Gemini |

### Customizing the Agent

Edit `agent.py` to modify:
- `instructions` - The system prompt for the agent
- Custom tools via `@agents.function_tool` decorators

---

## Deploying

### GCP Setup (First Time)

```bash
# Configure GCP APIs and service accounts
./setup_gcp.sh

# Push secrets to Secret Manager
./push_secrets.sh
```

### Deploy to GCE

```bash
# Default (ARM64 c4a-highcpu-1)
./deploy_gce.sh

# Cheap option (x86 e2-micro)
./deploy_gce.sh --micro
```

### View Logs

```bash
gcloud compute ssh gemini-live-agent --zone=us-central1-a --command='tail -f ~/agent.log'
```

### Architecture

```
Phone Call → LiveKit SIP → LiveKit Room → Agent (GCE) → Gemini Live API
```

The agent runs directly on a GCE VM (Debian). Secrets are fetched from Google Secret Manager at runtime.

---

## Testing

1. Call your LiveKit phone number
2. Say "Bamboo" → Agent responds with a limerick
3. Say "bop" → Agent logs the event
4. Say "end call" → Agent hangs up

---

## Related Docs

- [GCP_SETUP.md](GCP_SETUP.md) - Detailed GCP configuration
- [LIVEKIT_SETUP.md](LIVEKIT_SETUP.md) - LiveKit phone number setup
