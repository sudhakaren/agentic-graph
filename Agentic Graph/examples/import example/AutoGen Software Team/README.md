# Software Team

A sample [AutoGen](https://microsoft.github.io/autogen/) / [AG2](https://ag2.ai)
project for testing the Agentic Graph **Import AutoGen / AG2 Project** feature.

A group chat in which a manager orchestrates a user proxy and three assistant
agents to plan, build, and review a feature:

- **User Proxy** — represents the human; runs code (imported as a *human* node)
- **Planner** — turns a feature request into an implementation plan
- **Engineer** — writes the code; can call the `run_tests` tool
- **Reviewer** — reviews the code for correctness, security, and style
- **Manager** — the `GroupChatManager` that selects who speaks each round

## Graph shape

```
                      ┌─► User Proxy
                      ├─► Planner
Manager ──────────────┼─► Engineer ──► run_tests
                      └─► Reviewer
User Proxy ──► Manager        (initiate_chat)
```

The `GroupChatManager` is linked to its `GroupChat`, so the importer draws an
edge from the manager to each group member. `register_function(run_tests,
caller=engineer, …)` adds the Engineer → run_tests edge, and the
`initiate_chat` call adds User Proxy → Manager.

## How the importer reads it

AutoGen has no config file — agents and group chats are Python constructors.
The importer parses `team.py` for:

- `AssistantAgent` / `ConversableAgent` / `GroupChatManager` → agent nodes;
  `UserProxyAgent` → a human node.
- `GroupChat(agents=[…])` linked to a `GroupChatManager(groupchat=…)` →
  manager-to-member edges. (0.4-style teams — `RoundRobinGroupChat`,
  `SelectorGroupChat`, `Swarm` — chain their participants instead.)
- `initiate_chat` calls → directed edges.
- `tools=[…]` and `register_function(fn, caller=…)` → tool nodes + edges.

## Importing into Agentic Graph

**File → Import ▸ AutoGen / AG2 Project…**, then choose this folder. It imports
as 4 agent nodes (one of them a human node), 1 tool node, and 6 edges.

## Running it

This is a sample for import testing; to actually run it you would need an
AutoGen / AG2 environment:

```bash
pip install ag2
python team.py
```
