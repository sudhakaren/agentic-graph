# Analysis

The Analysis feature uses AI to review your agentic architecture against a library of known patterns and anti-patterns. It identifies design issues, highlights good practices, and suggests improvements.

> **Note:** Analysis is AI-assisted. Findings should be verified by a qualified reviewer.

## Running an analysis

1.  Ensure you have an LLM provider configured in [Settings](settings.md) (under Analysis \> LLM Provider).
2.  Choose **Analysis \> Analyze Architecture** (<kbd>⌘</kbd><kbd>⇧</kbd><kbd>A</kbd>), or click the play button in the Analysis tab of the Inspector.
3.  The analysis runs each pattern concurrently. Progress is shown in real time.
4.  Click the stop button to cancel a running analysis.

## Understanding findings

Each finding has a severity level:

| Severity | Meaning |
|----|----|
| Warning | An anti-pattern or design flaw that should be addressed. |
| Recommendation | A suggested improvement that would strengthen the architecture. |
| Positive | A good practice detected in the design. |
| Info | An observation that provides context but requires no action. |

## Filtering and navigation

Use the filter bar at the top of the Analysis tab to show only specific severity levels. Findings are grouped by category (Foundational, Operational, Security, Performance, etc.).

Each finding card may include related node chips — click one to select the node on the canvas, or double-click to also switch to the Properties tab.

## Pattern categories

The built-in pattern library covers:

- **Foundational** — Core architectural principles like agent-as-business-process, autonomy boundaries, and delegation chains.
- **Operational** — Runtime concerns like error handling, monitoring, timeouts, and recovery paths.
- **Security** — Authentication, data sensitivity, guardrails, and compliance.
- **Performance** — Latency budgets, caching, async patterns, and throughput.

## Fields analysed per component

Every pattern inspects the structured metadata on each node. Pattern signals reference fields by their **internal field name** — the same identifiers used in the `.ag` JSON format. When you write a custom pattern, use these exact names in the anti-pattern and positive signal text so the LLM can match them against node data.

The tables below list every field the built-in patterns reference. For each field you get: the label shown in the Inspector, the internal field name, the allowed values (enum members, boolean, or free text), and how the analysis engine uses it. For full conceptual descriptions, see the per-component reference pages.

> **Note:** All four node kinds (Agent, Tool, Knowledge, Human) share a **Risk** level that is serialised as `knowledgeRisk` (for historical compatibility with the original data model). Valid values: `none`, `low`, `medium`, `high`. Patterns cross-check this against guardrails, human oversight, and connected components regardless of the node kind.

### Agent fields

See [Agent Node](node-agent.md) for the full reference.

| Label | Field name | Values | Used for |
|----|----|----|----|
| Type | `agentType` | `worker`, `supervisor`, `router`, `specialist`, `orchestrator`, `custom` | Role consistency (Router shouldn't execute work), delegation chain validation, multi-agent orchestration checks. |
| Framework | `agentFramework` | `langchain`, `langgraph`, `crewai`, `watsonx`, `autogen`, `semanticKernel`, `openaiAgents`, `custom` | Framework-mixing risk detection, runtime compatibility checks. |
| Model | `agentModel` | Free text (e.g. `gpt-4o`, `claude-3.5-sonnet`) | Model-diversity flagging, complexity/model mismatch detection. |
| Role | `agentRole` | Free text | Cross-checked against connected tools/knowledge to confirm the role is supported. |
| Goal | `agentGoal` | Free text | Verified that connected components actually support the stated objective. |
| Instructions | `agentInstructions` | Free text (multi-line) | Flagged as operational risk if missing; checked for over-broad / under-focused wording (Monolithic Mega-Prompt). |
| Memory | `agentMemory` | `none`, `shortTerm`, `longTerm`, `both` | Stateful agents without persistence, stateless agents needing context, Invisible State anti-pattern detection. |
| Max Iterations | `agentMaxIterations` | Free text (e.g. `5`, `10`) | Agents without an iteration cap flagged as runaway-cost risk. |
| Delegation | `agentCanDelegate` | `true`, `false` | Delegation chain depth calculation, supervision requirement checks. |
| Complexity | `agentComplexity` | `deterministic`, `conditional`, `reasoning`, `openEnded` | Agent Washing detection (deterministic agents that should be tools), Open-Ended agents without guardrails. |
| Prompt Management | `agentPromptManagement` | `none`, `hardcoded`, `templated`, `versioned`, `registry` | Production systems with `none` flagged as governance gap. |
| Context Strategy | `agentContextStrategy` | `none`, `fixed`, `prioritised`, `windowed`, `compressed` | Long-running or multi-turn agents without a strategy flagged. |
| Observability | `agentObservability` | `none`, `basic`, `structured`, `full` | Agents with `none` flagged as operational risk. |
| Latency Budget | `agentLatencyBudget` | Free text (e.g. `300ms`, `3s`) | Cross-checked against sync tool count — tight budgets with many sync tools are flagged. |
| Cost Budget | `agentCostBudget` | Free text (e.g. `$0.10/call`) | Absence flagged as governance gap. |

### Tool fields

See [Tool Node](node-tool.md) for the full reference.

| Label | Field name | Values | Used for |
|----|----|----|----|
| Type | `toolType` | `openai`, `mcp`, `python`, `api`, `shell`, `langchain`, `flow`, `custom` | Tool soup detection (many `mcp` tools on one agent), `flow` tools recognised as workflow steps. |
| Category | `toolCategory` | `general`, `guardrail`, `monitoring`, `caching`, `testing`, `feedback`, `workflow`, `delivery`, `security`, `routing`, `extraction`, `processing` | Presence checks — e.g. high-risk agents without `guardrail` tools flagged; compliance processes without `workflow` tools flagged. |
| Execution (async) | `toolAsync` | `true`, `false` | Async tools without result handling flagged; sync tools on tight-latency agents flagged. |
| Inputs | `toolInputs` | Free text (schema description) | Missing inputs on critical tools flagged as reliability risk (Tool Data Overload). |
| Outputs | `toolOutputs` | Free text (schema description) | Combined with Inputs to assess contract completeness. |
| Auth Method | `toolAuthMethod` | `none`, `apiKey`, `oauth`, `bearerToken` | Sensitive-data tools with `none` flagged as security issue. |
| Endpoint | `toolEndpoint` | Free text (URL or connection string) | External endpoints checked for error handling and timeouts. |
| Timeout | `toolTimeout` | Free text (e.g. `5s`, `30s`) | Missing timeout flagged as latency/hang risk. |
| Error Handling | `toolErrorHandling` | `none`, `retry`, `fallback`, `skip`, `abort` | Critical-path tools with `none` flagged. |
| Idempotent | `toolIdempotent` | `true`, `false` | Non-idempotent tools paired with `retry` error handling flagged as correctness risk. |
| Data Volume | `toolDataVolume` | Free text (e.g. `small`, `large`, `>1MB/call`) | High-volume tools lacking pagination/streaming flagged; used by Sizing for data-plane estimates. |

### Knowledge fields

See [Knowledge Node](node-knowledge.md) for the full reference.

| Label | Field name | Values | Used for |
|----|----|----|----|
| Data Formats | `knowledgeDataFormats` | Free text (e.g. `PDF, JSON, CSV`) | Diverse formats without normalisation strategy flagged. |
| Size / Quantity | `knowledgeSizeQuantity` | Free text (e.g. `10GB`, `1M docs`) | Large sources without chunking or retrieval strategy flagged. |
| Location | `knowledgeLocation` | Free text (e.g. `S3`, `local`, `vendor API`) | Cross-checked against Sensitivity to flag confidential data on uncontrolled locations. |
| Access Method | `knowledgeAccessMethod` | Free text (e.g. `REST`, `SQL`, `filesystem`) | Verified to match data shape and retrieval strategy. |
| Sensitivity | `knowledgeSensitivity` | Free text (e.g. `public`, `internal`, `confidential`, `restricted`) | High-sensitivity sources without auth or guardrails flagged. |
| Update Frequency | `knowledgeUpdateFrequency` | Free text (e.g. `daily`, `realtime`) | Combined with Versioning Method to flag stale-data risk. |
| Versioning | `knowledgeVersioningMethod` | Free text (e.g. `git`, `snapshot`, `none`) | Frequently-updated sources without versioning flagged as auditability gap. |
| Retrieval Strategy | `knowledgeRetrievalStrategy` | `none`, `rag`, `sql`, `api`, `fullDocument`, `hybrid` | Strategy-to-content matching; Invisible State pattern checks for `sql`/`api` strategies. |
| Chunking Strategy | `knowledgeChunkingStrategy` | Free text (e.g. `fixed`, `recursive`, `semantic`) | Large sources without chunking strategy flagged. |
| Content Type | `knowledgeContentType` | Free text (e.g. `text`, `structured`, `binary`) | Influences which retrieval strategies are sensible. |

### Human fields

See [Human Node](node-human.md) for the full reference.

| Label | Field name | Values | Used for |
|----|----|----|----|
| Input Channel | `humanInputChannel` | `none`, `email`, `chat`, `phone`, `portal`, `api`, `sms`, `custom` | Channel suitability checks; content verification workflow detection. |
| Output Channel | `humanChannel` | `none`, `email`, `chat`, `phone`, `portal`, `api`, `sms`, `custom` | Asymmetric flow detection when compared with Input Channel; content delivery path validation. |
| Role | `humanRole` | Free text (e.g. `reviewer`, `approver`, `end user`) | Oversight role presence checks on high-risk agents. |
| Language | `humanLanguage` | Free text (e.g. `en`, `fr`) | Multi-language deployments without localisation flagged. |
| Timezone | `humanTimezone` | Free text (e.g. `UTC`, `Europe/Dublin`) | SLA and on-call coverage checks. |
| Auth Method | `humanAuthMethod` | Free text (e.g. `SSO`, `OAuth`, `password`) | Privileged humans with weak auth flagged. |
| Access Level | `humanAccessLevel` | Free text (e.g. `read-only`, `contributor`, `admin`) | Cross-checked with Role to detect privilege mismatches. |
| SLA / Response | `humanSLA` | Free text (e.g. `< 4h`, `next business day`) | Critical-path humans without SLA flagged. |
| Expected Behaviors | `humanBehaviors` | Free text | Verifies approvers and reviewers have defined responsibilities. |

### Example: referencing fields in a custom pattern

When you write a custom pattern in [Settings \> Analysis \> Patterns](settings.md), use the internal field names and enum values verbatim in the *Anti-pattern signals* and *Positive signals* text so the LLM can match them:

| Field | Example signal text |
|----|----|
|   | *Anti-pattern:* "Agents with `agentMemory=none` connected to no knowledge nodes, `agentObservability=none`, and `agentMaxIterations` unset." |
|   | *Positive:* "Agents with `agentMemory=shortTerm` or `agentMemory=longTerm`, `agentObservability=structured` or higher, and `toolCategory=guardrail` tools connected to all `agentType=supervisor` nodes." |

The LLM reads the graph as JSON with these exact field names, so matching them in the signal text produces far more accurate findings than referring to display labels.

## Custom patterns

You can manage the pattern library in [Settings](settings.md) under Analysis \> Patterns. Patterns can be enabled/disabled, imported from JSON files, or exported for sharing.

## Analysis depth

The LLM provider settings allow you to configure the analysis depth (standard or deep) and thinking level, which affect the thoroughness and cost of each analysis run.

## See Also

- [Inspector](inspector.md)
- [Settings](settings.md)
- [Sizing](sizing.md)
