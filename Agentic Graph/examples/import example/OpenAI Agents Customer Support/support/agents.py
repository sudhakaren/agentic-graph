"""Agent definitions for the customer support triage system.

A triage agent routes each request to one of three specialist agents. The
specialists use function tools (and one hosted web-search tool) to do the work.
"""
from agents import Agent, WebSearchTool

from support.tools import lookup_invoice, search_knowledge_base, process_refund


billing_agent = Agent(
    name="Billing Agent",
    handoff_description="Handles invoice questions, charges, and payment issues.",
    instructions="""You are a billing specialist. Look up invoices and explain charges clearly. Never speculate about amounts you have not verified with the invoice lookup tool.""",
    model="gpt-4o",
    tools=[lookup_invoice],
)

technical_agent = Agent(
    name="Technical Support Agent",
    handoff_description="Handles product troubleshooting and how-to questions.",
    instructions="""You are a technical support specialist. Use the knowledge base first and web search only when the knowledge base has no answer. Resolve the customer's problem step by step.""",
    model="gpt-4o",
    tools=[search_knowledge_base, WebSearchTool()],
)

refund_agent = Agent(
    name="Refund Agent",
    handoff_description="Handles refund requests and processes approved refunds.",
    instructions="""You are a refunds specialist. Confirm the invoice and the customer's eligibility before issuing a refund, and always record a clear reason.""",
    model="gpt-4o",
    tools=[process_refund],
)

triage_agent = Agent(
    name="Triage Agent",
    instructions="""You are the first point of contact for customer support. Read the request and hand off to the billing, technical, or refund agent. Do not try to resolve the issue yourself.""",
    model="gpt-4o-mini",
    handoffs=[billing_agent, technical_agent, refund_agent],
)
