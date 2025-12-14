import logging
import os
from dotenv import load_dotenv

from livekit import agents
from livekit.agents import AgentServer, AgentSession, Agent
from livekit.plugins import google
from google.cloud import secretmanager

load_dotenv()
logger = logging.getLogger("gemini-agent")


def fetch_secrets():
    """Fetch secrets from Google Secret Manager if running on GCP."""
    project_id = os.getenv("GCP_PROJECT")
    if not project_id:
        logger.warning("GCP_PROJECT not set, skipping Secret Manager fetch.")
        return

    client = secretmanager.SecretManagerServiceClient()
    keys = ["LIVEKIT_URL", "LIVEKIT_API_KEY", "LIVEKIT_API_SECRET", "GOOGLE_API_KEY"]

    for key in keys:
        if os.getenv(key):
            continue
        try:
            name = f"projects/{project_id}/secrets/{key}/versions/latest"
            response = client.access_secret_version(request={"name": name})
            value = response.payload.data.decode("UTF-8")
            os.environ[key] = value
            logger.info(f"Loaded {key} from Secret Manager")
        except Exception as e:
            logger.warning(f"Failed to load {key} from Secret Manager: {e}")


fetch_secrets()


class Assistant(Agent):
    """Voice assistant agent with custom tools."""

    def __init__(self) -> None:
        super().__init__(
            instructions="""You are a helpful voice assistant. Keep answers concise and conversational.
                            If the voice speaking to you says 'Bamboo':
                            Please respond by saying 'limerick', followed by a funny limerick...  DO NOT REPEAT THE LIMERICK.
                            If the voice speaking to you says 'bop', use the 'log_bop' tool to log it and continue the conversation.
                            If the voice speaking to you says 'end call', use the 'end_call' tool to hang up the call.
                         """
        )

    async def on_enter(self):
        """Called when the agent enters the session."""
        # Generate initial greeting
        self.session.generate_reply(instructions="Greet the user warmly and offer your assistance.")

    @agents.function_tool(description="End everything. Hang up the call immediately.")
    async def end_call(self):
        """Tool to hang up the call."""
        logger.info("ending the call")
        await self.session.aclose()

    @agents.function_tool(description="Log a bop")
    async def log_bop(self):
        """Tool to log when user says bop."""
        logger.info("heard a bop")
        return "Logged the bop!"


server = AgentServer()


@server.rtc_session()
async def my_agent(ctx: agents.JobContext):
    """Entrypoint for the agent session."""
    logger.info(f"connecting to room {ctx.room.name}")

    session = AgentSession(
        llm=google.realtime.RealtimeModel(
            model="gemini-2.0-flash-exp",
            voice="Puck",
            temperature=0.8,
        ),
    )

    await session.start(
        room=ctx.room,
        agent=Assistant(),
    )

    logger.info("agent started")


if __name__ == "__main__":
    agents.cli.run_app(server)
