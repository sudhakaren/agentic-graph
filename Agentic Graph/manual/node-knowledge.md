# Knowledge Node

A Knowledge node represents a data source that agents can query — a database, document store, vector index, API, file system, or any other information repository. Knowledge is what gives agents access to facts, context, and domain expertise beyond what's baked into their LLM weights.

Knowledge nodes have input ports only. They receive queries from agents or tools but don't initiate actions themselves. This reflects their passive nature — knowledge stores respond to requests rather than acting autonomously. In your graph, knowledge nodes are typically connected downstream of agents, representing the "what does the agent know?" question.

## Node Fields

### Title

The display name of the knowledge source, shown on the canvas and referenced in analysis findings and sizing reports. Use a name that identifies both the content and the source — "Customer FAQ Database", "Product Catalog (Postgres)", "Legal Policy Documents" — so reviewers immediately understand what data is available and where it lives.

### Risk

The risk level of the data in this knowledge source. This is primarily about data sensitivity rather than operational risk. A public FAQ is Low risk; a database containing personally identifiable information (PII), financial records, or medical data is High risk. The [Analysis](analysis.md) engine uses this field in conjunction with the Sensitivity field to flag knowledge sources that lack appropriate access controls or data classification. A High-risk knowledge source connected to an agent without guardrails will trigger security warnings. Values: None, Low, Medium, High.

## Knowledge Fields

### Data Formats

The file types or data formats stored in this knowledge source (e.g. "PDF, JSON, SQL, CSV" or "Unstructured text, HTML, Markdown"). This documents what the retrieval pipeline needs to handle. A knowledge source containing only structured JSON requires a very different ingestion pipeline than one containing scanned PDFs that need OCR. If your knowledge source contains mixed formats, list all of them — this helps identify potential ingestion challenges during architecture reviews.

### Size / Quantity

The volume of data in this knowledge source (e.g. "50 GB", "10,000 documents", "2 million rows", "500 PDF files"). Size directly impacts infrastructure requirements: a small FAQ of 100 documents can run on a single-node vector database, but a 50 GB corpus of legal documents needs significant storage, indexing infrastructure, and potentially distributed retrieval. The [Sizing](sizing.md) estimator flags large knowledge volumes as infrastructure risk areas that may need dedicated storage and retrieval infrastructure beyond the base compute estimates.

### Location

Where the data physically resides (e.g. "S3 bucket", "Postgres on RDS", "SharePoint site", "Pinecone vector DB", "Local file system"). This is essential for infrastructure planning — it determines network connectivity requirements, latency characteristics, and access control mechanisms. Knowledge stored in a cloud object store has different performance and cost profiles than knowledge in a managed database or a SaaS platform. For hybrid deployments, the location also affects data residency and compliance.

### Access Method

How agents retrieve data from this knowledge source (e.g. "REST API", "SQL query", "RAG pipeline with Pinecone", "GraphQL", "File read"). The access method determines the integration complexity and has significant performance implications. A direct SQL query is fast but tightly coupled; a RAG pipeline adds embedding and retrieval layers but provides semantic search. Document what the actual retrieval path looks like so reviewers can assess whether it's appropriate for the use case.

### Sensitivity

The data classification level (e.g. "Public", "Internal", "Confidential", "PII", "PHI", "Restricted"). This is a governance field that works alongside the Risk level. While Risk is about the consequences of misuse, Sensitivity is about the nature of the data itself. The [Analysis](analysis.md) engine checks sensitivity levels across your graph to identify patterns like: confidential data flowing to agents without guardrails, PII being processed without compliance tools, or sensitive data being cached without encryption. Use your organisation's data classification scheme if you have one.

### Update Frequency

How often the data in this knowledge source changes (e.g. "Real-time", "Hourly", "Daily", "Weekly", "Monthly", "Static"). This has important implications for your architecture:

- **Real-time or Hourly** — The data changes frequently. Caching strategies need short TTLs, and any RAG embeddings need to be refreshed regularly. Your retrieval pipeline needs to handle updates without downtime.
- **Daily or Weekly** — Batch updates are feasible. You can rebuild indexes and embeddings on a schedule. Caching is effective with daily invalidation.
- **Static** — The data rarely or never changes (e.g. historical records, published standards, archived documents). Aggressive caching is safe, and embeddings only need to be computed once. This is the easiest scenario for RAG.

Mismatches between update frequency and retrieval strategy are a common architectural issue — for example, using cached embeddings for real-time data.

### Versioning

How different versions of the data are tracked and managed (e.g. "Git", "timestamped snapshots", "database migrations", "S3 versioning", "none"). Versioning matters for reproducibility and auditing — if an agent gives a wrong answer, you need to know which version of the data it was working with. It's also critical for compliance in regulated industries where you may need to demonstrate what information was available at a specific point in time. "None" is acceptable for prototypes but is a governance gap in production systems.

### Retrieval Strategy

The method used to find relevant information within the knowledge source. This is one of the most impactful architectural decisions for knowledge-intensive agents:

- **None** — Not specified. Fill this in once you've decided on an approach.
- **RAG** — Retrieval-Augmented Generation. Documents are chunked, embedded into vectors, and stored in a vector database. At query time, the user's question is embedded and the most similar chunks are retrieved and provided to the LLM as context. This is the dominant approach for unstructured text and provides semantic (meaning-based) search.
- **SQL** — Structured queries against a relational database. Best for well-structured data with clear schemas. The agent (or a text-to-SQL tool) translates natural language into SQL queries. Precise and fast, but requires the data to be in a relational format.
- **API** — Programmatic access through a defined API. The knowledge source has its own query interface (e.g. a search API, a GraphQL endpoint). This wraps existing systems without needing to replicate their data.
- **Full Document** — The entire document is loaded into the LLM's context window. Only feasible for small documents that fit within context limits. No retrieval step is needed, but it consumes a lot of tokens and doesn't scale.
- **Hybrid** — A combination of approaches — for example, RAG for unstructured documents plus SQL for structured data, with a router that decides which path to use based on the query type. More complex to build but handles diverse data sources well.

### Chunking Strategy

How documents are split into pieces for retrieval (e.g. "512 tokens", "by paragraph", "by page", "semantic chunking", "sentence-level with overlap"). This is primarily relevant for RAG-based retrieval. Chunking strategy significantly affects retrieval quality:

- **Fixed token size** (e.g. 512 tokens) — Simple and predictable, but can split information across chunk boundaries.
- **By paragraph or section** — Preserves natural document structure. Works well for well-formatted documents.
- **Semantic chunking** — Uses NLP to split at topic boundaries. Produces more coherent chunks but is slower and more complex.
- **With overlap** (e.g. "512 tokens, 50 token overlap") — Adjacent chunks share some text at their boundaries, reducing the chance of important information being split.

If you're not using RAG, you can leave this blank.

### Content Type

The domain or subject matter of the content (e.g. "Legal contracts", "Technical documentation", "Customer FAQ", "Product specifications", "Policy documents", "Research papers"). This helps reviewers understand what kind of information the agent has access to and whether it's appropriate for the agent's stated goals. It also informs decisions about chunking, embedding models (some models are fine-tuned for specific domains), and retrieval strategies.

## Details

### Detail

Free-text notes for additional context. Use this for schema descriptions ("Main table: customers (id, name, email, plan_tier, created_at)"), access credentials location ("Credentials in AWS Secrets Manager under /prod/knowledge-db"), refresh procedures ("Embeddings rebuilt nightly at 2am UTC via the data-pipeline repo"), known limitations ("Search quality degrades for queries under 3 words"), or links to documentation.

## Ports

Knowledge nodes have input ports only, reflecting their role as passive data sources that respond to queries. You can add multiple custom-labelled input ports to represent different query types — for example, a "Search" input for semantic queries and a "Lookup" input for exact-match retrieval.

## Appearance

### Banner Color

The colour of the node's header banner on the canvas. Defaults to the standard knowledge colour (indigo). You might customise this to distinguish between different types of knowledge sources — for example, internal databases in one colour and external APIs in another.

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
- [Tool Node](node-tool.md)
- [Human Node](node-human.md)
