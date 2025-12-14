# LiveKit Setup Guide

This guide details the steps to configure **LiveKit Cloud** for the Gemini Live Voice Agent.

## Prerequisities
- A [LiveKit Cloud](https://cloud.livekit.io/) account.
- A project created within LiveKit Cloud.

## 1. API Keys
You need API credentials for your agent to connect to the LiveKit project.

1.  Navigate to **Settings** -> **Keys & Tokens**.
2.  Click **+ Add Standard Key**.
3.  **Description**: `GeminiVoiceAgent`.
4.  Click **Add Key**.
5.  Copy the **API Key** and **Secret Key**.
    - *Save these for your `.env` file later.*
    - **Note**: This key matches the permissions of your project (Admin). The Agent code uses this key to generate specific tokens for itself. there are no specific checkboxes to select here.

## 2. Phone Number
1.  Navigate to **SIP** -> **Phone Numbers** in the sidebar.
2.  Click **+ Purchase Number**.
3.  Search for a number (e.g., by area code) and complete the purchase.
4.  Once purchased, the number will appear in the list.

## 3. SIP Trunk & Dispatch Rule
This allows incoming calls to the phone number to be routed to your agent.

1.  Navigate to **SIP** -> **Inbound Trunks**.
    - Ensure your purchased number is listed here or in a Trunk. Usually, purchasing a number automatically handles the Trunking for you on LiveKit Cloud.
2.  Navigate to **SIP** -> **Dispatch Rules**.
3.  Click **+ New Dispatch Rule**.
4.  **Name**: `OmnichannelDispatch` (or any name).
5.  **Dispatch Rule**:
    - **Rule Type**: `Dispatch to Room`
    - **Room Name**: `sip-room` (This is the room your agent will join).
    - **Pin Code**: (Leave blank for public access).
6.  **Trunks**:
    - Select the Trunk/Number you just purchased.
7.  Click **Create Dispatch Rule**.

## 4. Verify
At this point, if you call the number, LiveKit will answer and try to put you into the room `sip-room`. Since no agent is running yet, you will likely hear silence or a "waiting" tone, but the connection logic is complete.
