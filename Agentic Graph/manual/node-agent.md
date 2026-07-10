# Agent Node

An Agent is the core decision-making unit in an agentic system. It receives inputs, reasons about them using a large language model, invokes tools to take actions, and produces outputs. In most architectures, agents are the nodes that orchestrate everything else — they decide what to do, when to delegate, and how to respond.

Agents have both input and output ports, meaning they can receive instructions from other agents or humans, and send results or delegate tasks downstream. A well-documented agent node gives you (and your team) a clear picture of what this agent is responsible for, how it behaves, and what infrastructure it needs.

## Node Fields

### Title

The display name of the agent, shown on the canvas and referenced throughout the app — in analysis findings, sizing reports, and node chips. Choose a name that clearly communicates the agent's purpose, like "Research Analyst" or "Order Processing Agent". This is the primary way other people reading your graph will identify what the agent does.

### Type

Describes the agent's structural role in your system. This isn't about what domain the agent works in, but rather how it relates to other agents in the architecture:

- **Worker** — Executes tasks directly. Most agents in a system are workers. They receive instructions, do the work (calling tools, reasoning over data), and return results.
- **Supervisor** — Manages a team of other agents. A supervisor decides which worker to assign a task to, monitors progress, and handles failures. If you have a group of specialised workers, you likely need a supervisor coordinating them.
- **Router** — Directs incoming requests to the right agent based on intent or content. Routers don't do the work themselves — they classify the request and forward it. Think of a router as a traffic controller at the front of your system.
- **Specialist** — Handles a specific domain or task type with deep expertise. Unlike a general worker, a specialist is optimised for a narrow set of scenarios (e.g. a "Legal Review Specialist" that only handles compliance questions).
- **Orchestrator** — Coordinates complex multi-agent workflows where the execution path isn't predetermined. An orchestrator dynamically decides which agents to involve and in what order, adapting the workflow based on intermediate results.
- **Custom** — For agent roles that don't fit the categories above.

### Risk

The risk level associated with this agent's actions and decisions. This is a critical field for governance — the [Analysis](analysis.md) engine uses it to flag high-risk agents that lack appropriate guardrails, monitoring, or human oversight. A "High" risk agent that can modify financial records or make external commitments without a guardrail tool will generate a warning. Set this based on what the agent can actually do, not what it's intended to do — if it has access to dangerous tools, it's high risk regardless of its instructions.

## Agent Fields

### Framework

The agent framework used to implement this agent. This documents your technology stack and helps anyone reading the graph understand what runtime environment the agent needs. If your team uses multiple frameworks across different agents, this field makes that visible at a glance. Options include LangChain, CrewAI, watsonx, AutoGen, Semantic Kernel, OpenAI Agents, and Custom.

### Model

The specific LLM model this agent uses for inference — for example `gpt-4o`, `claude-3.5-sonnet`, or `granite-3.1-8b`. This is important for several reasons: it determines the agent's reasoning capability, affects token costs, and influences latency. The [Sizing](sizing.md) estimator uses this field to assess your inference tier — a mix of models across agents suggests a more complex deployment. If left blank, Sizing assumes a general-purpose model.

### Role

A short description of the agent's persona or function — the "who" of the agent. Think of this as the agent's job title (e.g. "Research Analyst", "Customer Support Representative", "Data Validation Specialist"). This often maps directly to the system prompt's role definition. A clear role helps reviewers understand the agent's scope without reading its full instructions.

### Goal

What the agent is trying to achieve — its objective or mission statement. While the Role says who the agent is, the Goal says what it's working toward (e.g. "Find and summarise the top 5 relevant research papers" or "Resolve customer billing disputes within policy guidelines"). This is particularly valuable during architecture reviews, because it makes it easy to check whether the agent's connected tools and knowledge sources actually support its stated goal.

### Instructions

The full system prompt or detailed instructions given to the agent. This is a multi-line text field designed for longer content. You can paste the agent's actual system prompt here, or write a summary of its key behavioural rules. Having instructions documented in the graph means reviewers can assess whether the agent's behaviour is well-defined without needing to read the source code.

### Memory

How the agent retains context between interactions. Memory has a significant impact on both behaviour and infrastructure:

- **None** — Stateless. Each request is independent. Simplest to deploy and scale, but the agent has no recall of previous interactions.
- **Short Term** — Remembers within a single conversation or session. Context is maintained through the conversation but discarded afterward. This is the most common pattern for chat-based agents.
- **Long Term** — Remembers across conversations. Requires persistent storage (vector database, key-value store, etc.). Enables personalisation and learning but adds infrastructure complexity and data governance requirements.
- **Both** — Combines short-term conversation memory with long-term persistent memory. The most capable but also the most complex to implement and maintain.

The [Sizing](sizing.md) estimator factors memory type into infrastructure recommendations — long-term memory agents need additional storage and retrieval infrastructure.

### Max Iterations

The maximum number of reasoning/action loops the agent can perform per request. In a typical ReAct loop, the agent thinks, acts (calls a tool), observes the result, and then decides whether to continue or respond. Without a limit, an agent could loop indefinitely, consuming tokens and time. Setting this to a reasonable value (e.g. "5" or "10") is a critical safety measure. The [Sizing](sizing.md) estimator multiplies this by agent count to estimate total token consumption, and [Analysis](analysis.md) flags agents with no iteration limit as a risk.

### Delegation

Whether this agent can delegate tasks to other agents. When enabled, the agent can hand off sub-tasks to downstream agents, creating a chain of execution. This is powerful but has important infrastructure implications: each delegating agent can generate 5–15 concurrent inference requests as it fans out work to sub-agents. The [Sizing](sizing.md) estimator uses delegation depth (how many layers of delegation exist in your graph) to calculate peak concurrency. If you have a Supervisor delegating to 3 Workers who each delegate to 2 Specialists, that's a deep delegation chain with high concurrency potential.

### Complexity

The reasoning complexity of the agent, which directly affects token consumption and latency:

- **Deterministic** — Fixed rules with predictable outputs. May not even need an LLM — could be implemented as a simple function. Lowest token cost.
- **Conditional** — Simple branching logic based on input classification. Moderate token use — the agent makes decisions but follows well-defined paths.
- **Reasoning** — Multi-step inference requiring chain-of-thought. The agent needs to think through problems, weigh evidence, and make nuanced decisions. Higher token cost per interaction.
- **Open-Ended** — Creative, exploratory, or research tasks where the output isn't predictable. Highest token cost — the agent may need many iterations and long outputs.

The Sizing estimator uses complexity to scale token profile estimates. An architecture with many Open-Ended agents will have significantly higher inference costs than one with mostly Deterministic agents.

### Prompt Management

How the agent's prompts are managed over time. This matters more than people think — production systems need prompt versioning and governance:

- **None** — No prompt management strategy. Fine for prototypes, risky for production.
- **Hardcoded** — Static strings embedded in source code. Simple but inflexible — changing a prompt requires a code deployment.
- **Templated** — Parameterised templates with variable substitution. Allows customisation without changing the core prompt structure.
- **Versioned** — Prompts are tracked with version history, allowing rollback and A/B testing. Recommended for production systems.
- **Registry** — Centralised prompt registry that agents pull from at runtime. The most sophisticated approach — enables organisation-wide prompt governance and sharing.

### Context Strategy

How the agent handles its context window as conversations grow longer. Every LLM has a finite context window, and long conversations will eventually exceed it. Your strategy determines what happens when that limit approaches:

- **None** — No strategy. The agent uses whatever context fits and fails or truncates when it doesn't.
- **Fixed** — A fixed-size context window. Oldest messages are dropped when the limit is reached.
- **Prioritised** — Important messages (system prompt, key facts, recent messages) are kept while less important ones are dropped. Requires logic to rank message importance.
- **Windowed** — A sliding window of the N most recent messages. Simple and predictable, but the agent loses all earlier context.
- **Compressed** — Older context is summarised to save tokens while retaining key information. More complex to implement but preserves important context from earlier in the conversation.

### Observability

The level of runtime monitoring and tracing configured for this agent. Observability is essential for debugging, performance monitoring, and compliance in production systems:

- **None** — No monitoring. You're flying blind — if something goes wrong, you have no data to diagnose it.
- **Basic** — Logs and error reporting. You can see when things fail but have limited visibility into normal operation.
- **Structured** — Structured events and metrics (e.g. token counts, latency, tool call success rates). Enables dashboards and alerting.
- **Full** — Complete distributed tracing with spans, traces, and detailed telemetry. Every reasoning step, tool call, and decision is recorded. Essential for complex multi-agent systems where you need to trace a request across multiple agents.

The [Analysis](analysis.md) engine checks observability levels and flags agents with "None" as an operational risk.

### Latency Budget

The maximum acceptable response time for this agent — how long a user or calling agent will wait for a result. Express this as a time value like "300ms", "3s", or "5-8s". This field drives several important calculations: the [Sizing](sizing.md) estimator uses it to determine whether your system needs a conversational (sub-5-second) or task-execution (minutes) architecture. The [Analysis](analysis.md) engine flags agents with tight latency budgets that call many sync tools, since each tool call adds to the total response time.

### Expected Duration

A measured or known figure for how long this agent's own work takes — its reasoning and direct tool calls — expressed as a time value like "2s" or "5s". This field feeds the [Load Simulation](load-simulation.md) estimator: when it is set, the estimator uses your value for this agent's own time instead of calculating one from complexity, iterations, and tool calls. Time spent in agents this one delegates to is still added on top. Leave it blank to let the heuristic estimate the duration. Entering durations you have actually observed is the simplest way to make a latency estimate accurate. Unlike Latency Budget — a target you want to stay under — Expected Duration describes the agent's real behaviour.

### Cost Budget

The spending limit for this agent per call or per session (e.g. "\$0.10/call", "1000 tokens/request"). Cost budgets are a critical governance control — without them, a runaway agent loop can generate unbounded costs. The [Sizing](sizing.md) scaling recommendations check whether agents have cost budgets set and flag their absence as a cost risk. Even a rough estimate here helps — it signals that cost has been considered in the design.

## Details

### Detail

A free-text area for anything that doesn't fit in the structured fields above. Use this for design rationale ("We chose a Supervisor pattern here because..."), implementation notes ("Uses LangGraph with a custom state machine"), links to external documentation, known limitations, or open questions. This field is included in exported reports and documentation.

## Ports

Agents have both input and output ports. Ports are the connection points for edges — you create connections by dragging from one port to another on the canvas. You can add additional ports with custom labels to represent different types of input or output (e.g. an input port labelled "User Query" and another labelled "Context Data"). Custom port labels appear in the graph and help document the data flow.

## Appearance

### Banner Color

The colour of the node's header banner as displayed on the canvas. Defaults to the standard agent colour (blue), but you can customise it to create visual groupings or highlight specific agents. For example, you might colour all customer-facing agents green and all internal agents blue.

### Title Font Size

The size of the title text on the canvas (default 13). Increase this for agents that should stand out visually, like the primary orchestrator in your system.

### Title Font Color

The colour of the title text (default white). Adjust if you've chosen a light banner colour that makes white text hard to read.

## Lock

Lock states protect nodes from accidental changes during review or presentation. Click the lock button to cycle through states:

- **Unlocked** — Fully editable and movable. The default state.
- **Position Locked** — The node can't be moved on the canvas, but all fields remain editable. Useful when you've arranged your layout but are still filling in metadata.
- **Details Locked** — All fields are read-only, but the node can still be moved. Useful when the metadata is finalised but you're still adjusting the layout.
- **Fully Locked** — Cannot be moved or edited. Use this for reviewed and approved nodes that shouldn't change.

## See Also

- [All Node Types](node-types.md)
- [Tool Node](node-tool.md)
- [Knowledge Node](node-knowledge.md)
- [Human Node](node-human.md)
