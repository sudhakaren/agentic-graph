# Sizing

The Sizing tab in the Inspector provides infrastructure estimates based on the structure of your graph. Unlike Analysis, sizing is a pure calculation — no LLM is needed, and results update instantly as you modify the graph.

> **Note:** Estimates are based on graph structure and sizing rules of thumb. Actual requirements may vary based on workload characteristics, model choices, and deployment environment.

## Infrastructure tier

Your graph is classified into one of three tiers based on agent and tool count:

| Tier   | Condition                      | vCPU | RAM   |
|--------|--------------------------------|------|-------|
| Simple | 1 agent, 1 tool or fewer       | 1    | 5 GB  |
| Medium | Up to 5 agents, 10 tools       | 4    | 20 GB |
| Hard   | More than 5 agents or 10 tools | 18   | 90 GB |

These are per-100-user baselines. If your project has a Team Size set, values are scaled proportionally. Executor pods are calculated at a 1:4 vCPU-to-RAM ratio.

## Workload profile

Five dimensions characterise your workload:

Interaction Pattern  
How users interact — conversational (real-time chat, P95 \< 5s), task execution (async, minutes), event-driven (triggers, \< 1s), or mixed.

Concurrency  
Estimated simultaneous inference requests. A single session with delegating agents can generate 5–15 concurrent LLM calls.

Token Profile  
Estimated input and output token volumes per call and session, based on agent complexity and iteration limits.

External Calls  
Count of tools calling external APIs, split by async/sync. Tools without error handling are flagged.

Consistency  
Whether load is business-hours, global 24/7, or event-driven with spikes.

## Architecture decomposition

Your graph is mapped to a three-tier deployment model:

Front Door  
The entry point — should include caching, routing, and security tools.

Agent Runtime  
The core execution layer — agents, guardrails, monitoring, and workflow tools.

Inference  
The LLM backend — checks deployment target, model assignments, and testing tools.

Each tier shows which components are present and which expected components are missing.

## Scaling recommendations

A decision tree generates prioritised recommendations across four concern areas:

- **Latency** — Bottlenecks from sync tools, missing caching, or tight latency budgets.
- **Throughput** — Load handling gaps like missing monitoring or queue patterns.
- **Cost** — Spending controls like iteration limits, cost budgets, and model sizing.
- **Quality** — Reliability concerns like error handling, fallbacks, and circuit breakers.

## Caching assessment

Shows whether caching tools are present and estimates the potential impact. With prompt prefix caching, you can achieve 60–90% cost savings and 50–85% latency reduction. Idempotent tools are highlighted as candidates for result caching.

## Export

Use the toolbar export button (visible when the Sizing tab is active) to save the sizing report as Markdown or HTML. Reports include all sections plus a parameters appendix showing the configuration values used.

## Configuring parameters

All sizing thresholds and estimates are configurable in [Settings](settings.md) under Sizing \> Parameters. You can adjust tier boundaries, resource values, concurrency multipliers, caching estimates, and architecture component mappings.

## See Also

- [Inspector](inspector.md)
- [Analysis](analysis.md)
- [Load Simulation](load-simulation.md)
- [Settings](settings.md)
