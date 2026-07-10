# watsonx Orchestrate HR Assistant

A sample [IBM watsonx Orchestrate](https://www.ibm.com/products/watsonx-orchestrate)
ADK project for testing the Agentic Graph **Import watsonx Orchestrate Project**
feature.

An HR assistant that helps employees with benefits, time off, and payroll. A
top-level orchestrator agent routes each request to one of three specialist
collaborator agents, and answers general policy questions from a knowledge base.

- **HR Assistant** — the orchestrator; routes to the specialists and uses the
  HR policy knowledge base
- **Benefits Agent** — explains plans and enrols employees during open enrolment
- **Leave Agent** — checks leave balances and submits leave requests
- **Payroll Agent** — retrieves payslips and year-end tax documents

## Graph shape

```
                        ┌─► Benefits Agent ──┬─► lookup_benefits
                        │                    └─► enroll_in_plan
                        │
HR Assistant ──┬────────┼─► Leave Agent ─────┬─► check_leave_balance
               │        │                    └─► request_leave
               │        │
               │        └─► Payroll Agent ───┬─► get_payslip
               │                             └─► getTaxDocument
               │
               └─► hr_policy_kb (knowledge base)
```

## Project layout

A watsonx Orchestrate ADK project is a folder of specs, not a single config
file:

- `agents/*.yaml` — native agent specs (`spec_version` + `kind: native`).
  `collaborators:` lists the agents an orchestrator can route to, `tools:`
  lists the tools an agent can call, and `knowledge_base:` lists the knowledge
  bases it can search.
- `tools/hr_tools.py` — Python tools, each a function with an `@tool`
  decorator imported from `ibm_watsonx_orchestrate`.
- `tools/payroll_api.yaml` — an OpenAPI spec; each operation (here,
  `getTaxDocument`) becomes a tool.
- `knowledge_base/hr_policy_kb.yaml` — a knowledge base spec
  (`spec_version` + `kind: knowledge_base`).

## How the importer reads it

- Each agent YAML → an agent node. The agent with the most tools plus
  collaborators (**HR Assistant**) is treated as the orchestrator.
- Each `collaborators:` entry → an orchestrator-to-specialist edge.
- Each `@tool` function and each OpenAPI operation → a tool node, with an edge
  from every agent that lists it under `tools:`.
- Each knowledge base → a knowledge node, with an edge from every agent that
  lists it under `knowledge_base:`.

## Importing into Agentic Graph

**File → Import ▸ watsonx Orchestrate Project…**, then choose this folder. It
imports as 4 agent nodes, 6 tool nodes, 1 knowledge base, and 10 edges.

## Running it

This is a sample for import testing; to actually run it you would need a
watsonx Orchestrate environment and the ADK:

```bash
pip install -r requirements.txt
orchestrate server start
orchestrate knowledge-bases import -f knowledge_base/hr_policy_kb.yaml
orchestrate tools import -k python -f tools/hr_tools.py
orchestrate tools import -k openapi -f tools/payroll_api.yaml
orchestrate agents import -f agents/benefits_agent.yaml
orchestrate agents import -f agents/leave_agent.yaml
orchestrate agents import -f agents/payroll_agent.yaml
orchestrate agents import -f agents/hr_assistant.yaml
```
