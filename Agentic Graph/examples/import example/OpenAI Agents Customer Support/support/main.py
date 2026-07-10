"""Entry point — runs the customer support triage agent."""
import asyncio

from agents import Runner

from support.agents import triage_agent


async def main():
    result = await Runner.run(
        triage_agent,
        "I was charged twice for invoice INV-1042 — can I get a refund?",
    )
    print(result.final_output)


if __name__ == "__main__":
    asyncio.run(main())
