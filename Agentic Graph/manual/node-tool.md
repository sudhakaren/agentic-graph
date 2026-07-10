# Tool Node

A Tool is an external capability that agents can invoke — an API call, a database query, a script, a guardrail check, or any other discrete action. Tools are what give agents the ability to interact with the outside world. Without tools, an agent can only reason about text; with tools, it can search databases, send emails, process payments, and validate outputs.

Tools have both input and output ports. Input ports receive requests from agents (or other tools in a pipeline); output ports can feed results to downstream nodes. A well-documented tool node tells your team exactly what this capability does, how it's secured, and what happens when it fails.

## Node Fields

### Title

The display name of the tool, shown on the canvas and referenced in analysis findings, sizing reports, and caching assessments. Use a clear, action-oriented name that describes what the tool does — "Payment Gateway", "Document Search", "Email Sender" — rather than technical identifiers like "api_v2_endpoint_3".

### Risk

The risk level of this tool's operations. Think about what happens if this tool is called incorrectly or maliciously: a read-only search tool is Low risk, but a tool that transfers money or deletes records is High risk. The [Analysis](analysis.md) engine cross-references risk level with your architecture — a High risk tool connected directly to an agent with no guardrail tool in between will generate a warning. Values: None, Low, Medium, High.

## Tool Fields

### Type

The implementation technology behind this tool. This documents how the tool is built and what runtime it needs:

- **OpenAI** — An OpenAI function-calling tool. The agent describes the tool's schema to the LLM, which generates structured function calls. This is the most common pattern for agents built on OpenAI models.
- **MCP** — A Model Context Protocol server. MCP provides a standardised way for agents to discover and invoke tools, with built-in schema negotiation and streaming. Growing in adoption as a vendor-neutral tool protocol.
- **Python** — A Python function or script. The tool runs as Python code, either in-process or as a subprocess. Common for data processing, ML inference, and prototyping.
- **API** — A REST or GraphQL endpoint. The tool makes HTTP requests to an external service. The most common type for integrating with existing enterprise systems.
- **Shell** — A command-line tool or script. The tool executes a shell command and captures the output. Useful for system administration, file operations, or calling legacy tools.
- **LangChain** — A LangChain tool wrapper. LangChain provides a standardised tool interface with built-in parsing, validation, and error handling.
- **Flow** — A workflow or orchestration step. Rather than a single action, this tool represents a multi-step process (e.g. a CI/CD pipeline trigger or an approval workflow).
- **Custom** — For tool types that don't fit the categories above.

### Category

The functional role of this tool in your architecture. Category is one of the most important fields for tools because the [Sizing](sizing.md) estimator uses it to map tools to architecture tiers (Front Door, Agent Runtime, Inference) and to identify caching candidates. Choose the category that best describes what this tool does for the system:

- **General** — A standard business-logic tool that doesn't fit a specific infrastructure category.
- **Guardrail** — Validates, filters, or constrains agent behaviour. Guardrail tools are checked by Analysis — agents with High risk and no connected guardrail tool trigger warnings.
- **Monitoring** — Observes system behaviour, logs events, or reports metrics. Mapped to the Agent Runtime architecture tier.
- **Caching** — Stores and retrieves cached data to reduce redundant computation or API calls. The presence of caching tools dramatically affects Sizing estimates — prompt prefix caching alone can deliver 60–90% cost savings.
- **Testing** — Validates outputs, runs assertions, or performs quality checks. Mapped to the Inference architecture tier.
- **Feedback** — Collects user feedback, ratings, or corrections. Important for continuous improvement loops.
- **Workflow** — Manages multi-step processes, state machines, or approval chains. Mapped to the Agent Runtime tier.
- **Delivery** — Sends outputs to users or external systems (email, notifications, file generation).
- **Security** — Handles authentication, authorisation, encryption, or audit logging. Mapped to the Front Door architecture tier.
- **Routing** — Directs requests to the appropriate handler based on content or rules. Mapped to the Front Door tier.
- **Extraction** — Pulls data from documents, images, or structured sources.
- **Processing** — Transforms, aggregates, or enriches data.

### Execution

Whether the tool runs synchronously or asynchronously. This has major implications for your system's performance characteristics:

- **Sync** — The calling agent waits for the tool to complete before continuing. Simple to reason about, but every sync tool call adds directly to the agent's response time. If an agent calls three sync tools sequentially, each taking 2 seconds, that's 6 seconds of latency just from tool calls.
- **Async** — The agent can continue working (or call other tools) while this tool runs in the background. Enables parallelism and better throughput, but requires callback handling and makes the control flow more complex. The agent needs to know how to handle the result when it arrives.

The [Sizing](sizing.md) estimator counts sync vs async tools to assess concurrency patterns and generate scaling recommendations. A system with all sync tools has a simpler execution model but potential latency bottlenecks.

### Inputs

The parameters the tool accepts, documented as a brief schema (e.g. "query: String, limit: Int, filters: \[String\]"). This is the tool's interface contract — what an agent needs to provide when calling it. Clear input documentation helps during architecture reviews because reviewers can verify that the calling agent has access to the data the tool requires.

### Outputs

What the tool returns (e.g. "results: \[Document\], total_count: Int"). Documents the response format so downstream consumers know what to expect. Like Inputs, this helps verify that the data flow through your graph is coherent — that the output of one tool matches what the next node in the chain needs.

### Auth Method

How the tool authenticates with its backend service. This is critical security metadata:

- **None** — No authentication required. Acceptable for internal tools on a private network, but a red flag for anything internet-facing.
- **API Key** — A static key sent in request headers. Simple but requires key rotation and secure storage.
- **OAuth** — OAuth 2.0 flow with token exchange. More secure and supports scoped permissions, but adds complexity.
- **Bearer Token** — A JWT or similar token sent in the Authorization header. Common for service-to-service communication.

The [Analysis](analysis.md) engine checks auth methods as part of its security pattern evaluation — tools accessing external services with "None" authentication are flagged.

### Endpoint

The URL or address of the tool's service (e.g. "https://api.example.com/v1" or "grpc://internal-service:50051"). Documents where the tool connects to, which is essential for infrastructure planning, network policy configuration, and troubleshooting. For internal tools, this might be a service mesh address; for external tools, it's the API's public URL.

### Timeout

The maximum time in seconds before the tool call is abandoned (e.g. "30"). Without a timeout, a tool call to an unresponsive service will hang indefinitely, blocking the agent and consuming resources. The [Analysis](analysis.md) engine flags tools without timeouts as operational risks. Set timeouts based on the tool's expected response time plus a reasonable buffer — if the tool normally responds in 2 seconds, a 10-second timeout gives plenty of headroom while still protecting against hung connections.

### Expected Duration

A measured or known figure for how long one call to this tool takes — for example "800ms" or "1.5s". This field feeds the [Load Simulation](load-simulation.md) estimator: when it is set, the estimator uses your value instead of the generic per-type estimate. If you have measured a tool's real response time, entering it here is the single most effective way to improve a latency estimate. Durations accept milliseconds ("800ms"), seconds ("1.5s"), or a range ("2-4s", which resolves to the upper bound). This is distinct from Timeout: Timeout is the point at which a slow call is abandoned, whereas Expected Duration is how long the call normally takes when it succeeds.

### Error Handling

What happens when the tool call fails. This is one of the most important operational fields because tool failures are inevitable in production:

- **None** — No error handling. The failure propagates up to the agent, which may or may not handle it gracefully. This is flagged by [Analysis](analysis.md) as a risk because unhandled tool errors can crash agent loops or produce incorrect outputs.
- **Retry** — Automatically retry the call (typically with exponential backoff). Good for transient failures like network timeouts or rate limiting, but dangerous for non-idempotent operations — retrying a payment tool could charge the customer twice.
- **Fallback** — Use an alternative tool or cached result when the primary tool fails. Provides graceful degradation but requires a fallback path to be designed and tested.
- **Skip** — Continue the workflow without the tool's result. Appropriate when the tool's output is optional or enrichment-only (e.g. a sentiment analysis step that adds value but isn't required).
- **Abort** — Stop the entire workflow and report the error. The safest option for critical tools where proceeding without their result would produce wrong or dangerous outcomes.

### Idempotent

Whether calling the tool multiple times with the same input always produces the same result with no side effects. A search tool is idempotent — searching for "quarterly report" ten times returns the same results. A "send email" tool is not — calling it ten times sends ten emails. This field matters for two reasons: idempotent tools are safe to retry on failure, and the [Sizing](sizing.md) estimator highlights idempotent tools as candidates for result caching, which can significantly reduce costs and latency.

### Data Volume

The typical size of data the tool handles per call (e.g. "Small", "Large", "Paginated", "10KB per request", "Up to 50MB"). This helps assess infrastructure requirements — tools that process large data volumes may need more memory, longer timeouts, and streaming support. It also affects network planning and cost estimation.

## Details

### Detail

Free-text notes for anything that doesn't fit the structured fields. Use this for rate limit documentation ("Max 100 requests/minute, 429 responses trigger backoff"), implementation notes ("Wraps the internal DocumentService gRPC API"), known issues ("Returns empty results for queries under 3 characters"), dependencies ("Requires the auth-service to be running"), or links to API documentation.

## Ports

Tools have both input and output ports. Input ports receive invocation requests from agents or other tools; output ports can feed results downstream. You can add multiple custom-labelled ports to represent different interaction types — for example, a "Query" input and an "Error" output alongside the standard "Result" output.

## Appearance

### Banner Color

The colour of the node's header banner on the canvas. Defaults to the standard tool colour (orange). You might customise this to visually group tools by category — for example, all security tools in red, all caching tools in green.

### Title Font Size

The size of the title text on the canvas (default 13).

### Title Font Color

The colour of the title text (default white).

## Lock

Lock states protect nodes from accidental changes. Click the lock button to cycle through states:

- **Unlocked** — Fully editable and movable.
- **Position Locked** — Can't be moved, but fields are editable.
- **Details Locked** — Fields are read-only, but the node can be moved.
- **Fully Locked** — Cannot be moved or edited.

## See Also

- [All Node Types](node-types.md)
- [Agent Node](node-agent.md)
- [Knowledge Node](node-knowledge.md)
- [Human Node](node-human.md)
