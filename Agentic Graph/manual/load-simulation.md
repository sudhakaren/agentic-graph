# Load Simulation

The Load Simulation tab in the Inspector estimates how long a selected agent takes to respond. Like Sizing, it is a pure calculation — no LLM is needed, and the estimate updates instantly as you modify the graph or its timing parameters.

> **Note:** Load Simulation is a **beta** feature. It currently estimates per-agent latency; whole-solution simulation and latency-vs-load charts are planned for a future release.

## Using the tab

Select the Load Simulation tab (the line-chart icon) in the Inspector's segmented control, then select a single Agent node on the canvas. The tab shows an estimate for that agent and all the work it triggers. With nothing selected, with an edge or a non-agent node selected, or with several nodes selected, the tab simply prompts you to select one agent.

## Typical and p95

Two headline figures summarise the estimate:

Typical  
The latency of an ordinary run — the agent uses a fraction of its iteration budget and tools respond at their expected speed.

p95  
A worst-case run near the 95th percentile — the agent uses most of its iteration budget and a tail-variability multiplier is applied on top. Size timeouts and capacity against this figure, not the typical one.

## Latency budget

If the selected agent has a [Latency Budget](node-agent.md) set, the tab compares it against the p95 estimate. A green checkmark confirms the estimate is within budget; an orange warning means the p95 estimate exceeds it, and the p95 figure itself is highlighted. This makes it easy to spot agents at risk of breaching their response-time targets before you deploy.

## Typical breakdown

The breakdown shows where the typical time goes:

- **LLM inference** — Time spent in the agent's reasoning loops. Each loop is one LLM call; the per-call time depends on the agent's [Complexity](node-agent.md), and the loop count is derived from its Max Iterations.
- **Sync tools** — Synchronous tool calls run one after another, so their times add up.
- **Async tools** — Asynchronous tool calls overlap, so only the slowest one contributes.
- **Delegated agents** — The combined time of every agent this one delegates to, followed recursively down the chain.

When an agent has an Expected Duration set, its inference and tool rows are replaced by a single **Agent processing** row — the override stands in for the whole heuristic (see below).

## Sync-to-async hint

When an agent calls synchronous tools, the tab also estimates what the typical latency would be if those tools ran asynchronously instead. If the saving is meaningful, a hint shows the lower figure — a quick way to spot agents where switching a tool's Execution mode to Async would pay off.

## How the estimate works

Starting from the selected agent, the estimator adds up:

- The agent's reasoning loops — loop count × the per-call inference time for its complexity.
- Its synchronous tool calls, summed, plus its slowest asynchronous tool call.
- Every delegated agent's full subtree, summed down the chain. Cycles are detected so no agent is counted twice.

Tools are counted once per run, not once per reasoning loop — only the LLM "thinking" repeats per loop. The p95 figure uses a higher share of the iteration budget and then applies a tail multiplier.

## Expected Duration override

Every Agent and Tool node has an **Expected Duration** field. When set, it overrides the heuristic for that node — the estimator uses your value instead of one calculated from complexity or tool type. This is the most reliable way to sharpen an estimate: if you have measured a tool's real response time or an agent's real processing time, enter it. Durations accept values like `800ms`, `1.5s`, or a range such as `2-4s` (a range resolves to its upper bound). A number with no unit, or any unit other than `ms`, is read as seconds.

## Configuring parameters

The rule-of-thumb timings — inference time per complexity level, tool time per type, the typical and p95 iteration fractions, and the p95 tail multiplier — are all configurable in [Settings](settings.md) under Latency \> Parameters. Tune them to match what you observe in your own systems; the estimate updates immediately.

## See Also

- [Inspector](inspector.md)
- [Sizing](sizing.md)
- [Agent Node](node-agent.md)
- [Settings](settings.md)
