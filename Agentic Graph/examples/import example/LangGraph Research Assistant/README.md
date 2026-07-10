# Research Assistant

A sample [LangGraph](https://langchain-ai.github.io/langgraph/) project for
testing the Agentic Graph **Import LangGraph Project** feature.

It defines a `StateGraph` research assistant with a tool-calling loop and a
writer/reviewer revision loop:

- **planner** — breaks the question into sub-questions
- **researcher** — investigates sub-questions, calling tools when needed
- **tools** — a `ToolNode` bundling `web_search` and `fetch_url`
- **writer** — drafts the report
- **reviewer** — critiques the draft and decides whether to revise

## Graph shape

```
START ─► planner ─► researcher ──(call_tools)──► tools ─┐
                        ▲                                │
                        └────────────────────────────────┘
                        │
                        └──(done)──► writer ─► reviewer ──(revise)──► writer
                                                        └─(approve)─► END
```

`START` and `END` are LangGraph flow markers, not real nodes, so the importer
drops edges that touch them. The remaining graph imports as four agent nodes
(planner, researcher, writer, reviewer), one tool node (tools), and six edges.

## How the importer reads it

LangGraph has no config file — the structure lives in Python. The importer
parses `research_assistant/graph.py` for:

- `add_node("name", fn)` — each becomes a node. A `ToolNode(...)` wrapper (or a
  node named `tools` / `action`) becomes a tool node; everything else is an
  agent node.
- `add_edge("a", "b")` — direct edges (edges via `START` / `END` are dropped).
- `add_conditional_edges("src", router, {...})` — one edge per destination in
  the path map.

Node functions' docstrings (from `nodes.py`) are pulled in as the node detail.

## Importing into Agentic Graph

**File → Import ▸ LangGraph Project…**, then choose this folder.

## Running the graph

This is a sample for import testing; to actually run it you would need a
LangGraph environment:

```bash
pip install langgraph langchain-core
langgraph dev
```
