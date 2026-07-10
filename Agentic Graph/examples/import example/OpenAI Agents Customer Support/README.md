# Customer Support

A sample [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/)
project for testing the Agentic Graph **Import OpenAI Agents SDK Project**
feature.

A triage agent routes each customer request to one of three specialists:

- **Triage Agent** — first point of contact; hands off to a specialist
  (`handoffs=[billing, technical, refund]`)
- **Billing Agent** — invoice and payment questions (tool: `lookup_invoice`)
- **Technical Support Agent** — troubleshooting (tools: `search_knowledge_base`,
  hosted `WebSearchTool`)
- **Refund Agent** — refund requests (tool: `process_refund`)

## Graph shape

```
                 ┌─► Billing Agent ──► lookup_invoice
Triage Agent ────┼─► Technical Agent ─► search_knowledge_base
                 │                    └► Web Search Tool
                 └─► Refund Agent ───► process_refund
```

## How the importer reads it

The OpenAI Agents SDK has no config file — agents are Python `Agent(...)`
constructors. The importer parses `support/agents.py` for:

- `Agent(name=…, instructions=…, model=…)` — each becomes an agent node.
- `handoffs=[…]` — each handoff target becomes an agent-to-agent edge.
- `tools=[…]` — `@function_tool` functions and hosted tools (e.g.
  `WebSearchTool()`) become tool nodes; an `agent.as_tool(…)` reference becomes
  an agent-to-agent edge instead.

`@function_tool` docstrings (from `support/tools.py`) become the tool detail.

## Importing into Agentic Graph

**File → Import ▸ OpenAI Agents SDK Project…**, then choose this folder. It
imports as 4 agent nodes, 4 tool nodes, and 7 edges.

## Running it

This is a sample for import testing; to actually run it you would need an
OpenAI Agents SDK environment:

```bash
pip install openai-agents
python -m support.main
```
