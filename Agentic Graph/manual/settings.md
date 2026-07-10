# Settings

Access Settings by clicking the gear button at the bottom of the sidebar palette, or by choosing **Agentic Graph \> Settings** from the menu bar (<kbd>⌘</kbd><kbd>,</kbd>). The settings view replaces the workspace in the current window — click the back arrow to return to your graph. Settings are stored in your Application Support folder and persist across all projects and sessions.

Settings are organised into sections in the left sidebar: General (the application language), Components, Annotations, and Shapes (for node defaults), Analysis (the LLM provider, configuration, pattern library, and Prompt Analysis), Sizing (for infrastructure calculation parameters), and Latency (for the latency estimator's timings).

## General

### Language

Agentic Graph is localised into 14 languages: English, Spanish, French, German, Brazilian Portuguese, Italian, Greek, Polish, Turkish, Czech, Arabic, Finnish, Japanese, and Korean. The Language picker sets the language for the whole interface. Because the language is applied as the app starts, a change takes effect after a restart — when you pick a new language you can choose to restart immediately or to apply it on the next launch. The choice is stored with your other settings and is independent of the macOS system language.

## Node Defaults

Node defaults control the initial appearance and metadata of newly created nodes. When you drag a node type from the sidebar palette onto the canvas, it inherits the defaults configured here. Changes to defaults only affect nodes created after the change — existing nodes on the canvas are not modified.

### Components

Default settings for Agent, Tool, Knowledge, and Human nodes. Each component type has its own settings page with:

- **Default colour** — The banner colour that new nodes of this type will have. Useful if your team has a colour convention (e.g. all agents blue, all tools orange) and you want to enforce it from the start.
- **Default size** — The initial width and height of new nodes on the canvas.
- **Default font size** — The title text size for new nodes.
- **Default metadata values** — Pre-fill metadata fields so new nodes start with sensible values. For example, you might set the default Agent framework to "LangChain" if that's what your team uses, or set the default Tool error handling to "Retry" so new tools don't start with "None".

Setting good defaults saves time and promotes consistency across your team. If everyone on your project uses the same framework and deployment model, configure those as defaults rather than filling them in manually on every node.

### Annotations

Default appearance for Comment nodes — colour, size, and font size. Comments are visual annotations with no functional metadata, so their defaults are purely about appearance.

### Shapes

Default appearance for Rectangle, Rounded Rectangle, Oval, and Text shape nodes. Each shape type has its own settings for line colour, fill colour, fill enabled/disabled, and size. Text shapes additionally have font size and text colour defaults.

## Analysis

### LLM Provider

The AI model configuration used for architecture analysis. Analysis requires an LLM to evaluate your graph against the pattern library, so this must be configured before you can run an analysis.

### Provider

The LLM service to connect to. The available providers depend on what's supported by the app. Each provider has its own authentication method and model catalog.

### API Key

Your authentication credential for the selected provider. This is stored locally on your Mac in the Application Support folder — it is never transmitted anywhere except to the selected LLM provider during analysis. If your organisation requires API keys to be rotated, remember to update this when the key changes. The app does not validate the key until you run an analysis, so check for authentication errors in the analysis output if things aren't working.

### Model

The specific model to use for analysis (e.g. a particular model version or size). Larger, more capable models produce more nuanced analysis findings but cost more per run and take longer. For routine checks during development, a smaller model may be sufficient; for a formal architecture review, use the most capable model available. The model choice doesn't affect which patterns are evaluated — all enabled patterns run regardless — but it affects the quality of the LLM's reasoning about each pattern.

### Analysis Depth

Controls how thoroughly the LLM evaluates each pattern. Standard depth gives faster, more concise results suitable for iterative development. Deep analysis takes longer but produces more detailed reasoning, considers more edge cases, and is more likely to catch subtle issues. Use deep analysis for formal reviews and milestone checkpoints.

### Thinking Level

Controls the reasoning effort of the model. Higher thinking levels allow the model to spend more time reasoning through complex patterns before producing findings. This is particularly valuable for patterns that require understanding the relationships between multiple nodes (e.g. "does this agent have a fallback path if its primary tool fails?") rather than just checking individual node properties. Higher thinking levels increase both quality and cost.

### Analysis Patterns

The pattern library is the heart of the analysis feature. Each pattern describes an architectural concern that the LLM evaluates against your graph. The built-in library ships with patterns covering Foundational, Operational, Security, and Performance categories.

In the Patterns settings page you can:

- **Enable or disable individual patterns** — Turn off patterns that aren't relevant to your project. For example, if you're building an internal tool with no compliance requirements, you might disable the compliance-related patterns to reduce noise in your analysis results.
- **Filter by category** — View patterns in a specific category to manage them as a group.
- **Import patterns** — Load patterns from a JSON file. You can choose to merge (add new patterns while keeping existing ones) or replace (overwrite the entire library). This is how you share custom patterns across a team — one person creates the patterns, exports them, and everyone else imports the file.
- **Export patterns** — Save the current pattern library to a JSON file for sharing or backup.
- **Reset to defaults** — Restore the built-in pattern library, discarding any customisations. Use this if your pattern library gets into a bad state or if you want to start fresh after a major update.

Custom patterns follow the same structure as built-in ones: a name, category, severity level, description of what to look for, and the evaluation prompt that the LLM uses to check the pattern against your graph. Creating effective custom patterns requires understanding both the architectural concern you're checking for and how to prompt an LLM to evaluate it accurately.

### Prompt Analysis

Settings for the [Prompt Analysis](prompt-analysis.md) tab. Two translation languages control the translate buttons that appear next to the prompt field: a primary target and an optional reverse target. Leaving a language blank hides its button.

The page also exposes the two prompts that drive the analysis — the **system prompt** sent to the model, and the **user message template**. The template supports placeholders (`{{framing}}`, `{{agentContext}}`, and `{{prompt}}`) that are filled in for each run. Editing these changes how the analysis behaves; a Reset button restores each one to its default.

## Sizing

### Parameters

All values used by the [Sizing](sizing.md) estimator are configurable here. The defaults are based on general industry rules of thumb for agentic workloads, but every system is different — adjust these to match your specific environment, infrastructure costs, and performance requirements.

### Tier Thresholds

The agent and tool count boundaries that determine which sizing tier a graph falls into. Each tier has four configurable values:

- **Max Agents** — The maximum number of agents for this tier. If your graph has more agents than this threshold, it moves to the next tier up.
- **Max Tools** — The maximum number of tools for this tier. Like agents, exceeding this threshold bumps the graph to the next tier.
- **vCPU** — The number of virtual CPU cores allocated for this tier (per base user count).
- **RAM (GB)** — The amount of memory in gigabytes allocated for this tier (per base user count).

The default tiers are: Simple (1 agent, 1 tool, 1 vCPU, 5 GB), Medium (5 agents, 10 tools, 4 vCPU, 20 GB), Hard (unlimited, 18 vCPU, 90 GB). If your infrastructure uses different instance types or has different cost profiles, adjust these to match. For example, if your cloud provider's standard instance has 8 vCPU and 32 GB RAM, you might adjust the Medium tier to match that instance size.

### Base User Count

The baseline number of users that the tier resource values are calculated for (default 100). All vCPU and RAM values in the tier table are "per this many users". When the [Team Size](project-metadata.md) in your project metadata differs from this baseline, the Sizing estimator scales resources proportionally. For example, if the base is 100 users and your Team Size is 500, resource estimates are multiplied by 5. Adjust this if your organisation's standard sizing methodology uses a different baseline (e.g. 50 users, 1000 users).

### Concurrency Multiplier

The range of concurrent inference requests generated by each delegating agent. The defaults (5 low, 15 high) represent the observation that a single agent with delegation enabled can fan out work to multiple sub-agents, each requiring their own LLM inference call. The Sizing estimator uses the low and high values to generate a concurrency range in the workload profile.

If your agents use simple delegation (one agent delegates to one other), the low end is appropriate. If you have complex orchestration patterns where a supervisor fans out to many workers simultaneously, increase the high end. For systems with no delegation at all, these values don't affect the calculations since only delegating agents trigger the multiplier.

### Caching Estimates

The estimated impact of caching on cost and latency, expressed as percentage ranges:

- **Cost savings (min/max %)** — The percentage reduction in inference costs when caching tools are present. Defaults: 60–90%. Prompt prefix caching (reusing computed attention from static prompt prefixes) is the primary driver. The actual savings depend on how much of your prompts are static vs dynamic — agents with long, stable system prompts benefit most.
- **Latency reduction (min/max %)** — The percentage reduction in response time when caching tools are present. Defaults: 50–85%. Cached prompt prefixes skip the computation for the cached portion, directly reducing time-to-first-token. The actual reduction depends on the ratio of cached to uncached tokens in each request.

If your system has been in production and you have real caching metrics, replace the defaults with your actual observed values. If you're using a provider that doesn't support prompt caching, set these to 0% to remove caching from the estimates.

### Architecture Components

Maps tool categories to the three architecture tiers (Front Door, Agent Runtime, Inference). This controls how the Sizing estimator's [architecture decomposition](sizing.md) determines which components are present in each tier and which are missing.

Each tier shows a list of tool categories as toggle chips. If a category is toggled on for a tier, the Sizing estimator will check whether your graph has tools of that category and mark them as present or missing in the architecture view:

- **Front Door** — The entry point tier. By default includes Caching, Routing, and Security categories. These are the tools that handle request throttling, authentication, and caching before requests reach the agent layer.
- **Agent Runtime** — The core execution tier. By default includes Guardrail, Monitoring, Workflow, and Feedback categories. These are the tools that support agents during execution — validating outputs, tracking performance, managing workflows, and collecting feedback.
- **Inference** — The LLM backend tier. By default includes Testing categories. This tier also checks for deployment target and model assignments, but the tool category mapping specifically checks for testing and validation tools in the inference layer.

If your organisation uses a different architectural model (e.g. a four-tier architecture with a separate data tier), you can adjust the mappings to match. Add categories to the tier where they're architecturally relevant, and remove categories that don't apply.

### Reset to Defaults

Restores all sizing parameters to their original values. Use this if you've been experimenting with values and want to return to the baseline, or if parameter changes have produced unexpected results and you want a known-good starting point. A confirmation dialog prevents accidental resets.

## Latency

### Parameters

All timings used by the [Load Simulation](load-simulation.md) estimator are configurable here. The defaults are general rules of thumb for agentic workloads — replace them with figures you have measured in your own environment for a more accurate estimate. Changes take effect immediately.

### Agent Inference Time

The number of seconds one LLM call takes, broken down by agent [Complexity](node-agent.md) — Deterministic, Conditional, Reasoning, and Open-ended. A reasoning step costs more than a deterministic one, so more complex agents are estimated to spend longer in each reasoning loop.

### Tool Call Latency

The number of seconds one tool call takes, broken down by tool [Type](node-tool.md) — OpenAI, MCP, Python, API, Shell, LangChain, Flow, and Custom. These figures are used for any tool that does not have its own Expected Duration set. Synchronous tool times add up; asynchronous tools overlap, so only the slowest one counts.

### Reasoning Loops

How much of an agent's Max Iterations budget is actually executed, expressed as a fraction:

- **Typical fraction** — The share of the iteration limit used in an ordinary run (default 0.35). An agent with a limit of 10 runs roughly 4 loops in a typical case.
- **p95 fraction** — The share used in a worst-case run (default 0.9). Most of the iteration budget is consumed.

### Tail Estimate

The **p95 call multiplier** (default 1.6×) is applied on top of the p95 reasoning loops to account for tail variability — slow network hops, queueing, and cold starts that a typical run avoids. This is what separates the p95 headline figure from the typical one.

### Reset to Defaults

Restores all latency parameters to their original values. A confirmation dialog prevents accidental resets.

## See Also

- [Analysis](analysis.md)
- [Sizing](sizing.md)
- [Load Simulation](load-simulation.md)
- [Node Types](node-types.md)
- [Project Metadata](project-metadata.md)
