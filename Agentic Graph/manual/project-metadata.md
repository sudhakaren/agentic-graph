# Project Metadata

When no node or edge is selected, the Properties tab shows the project-level metadata form. This is where you document the "why", "when", "how big", and "how risky" of your agentic system — the context that surrounds the graph itself.

Project metadata serves several purposes beyond simple documentation. The [Sizing](sizing.md) estimator uses Team Size and Deployment Target to scale infrastructure recommendations. The [Analysis](analysis.md) engine checks Risk Level, Compliance Requirements, and Data Classification when evaluating security and governance patterns. And when you export reports (HTML or Markdown), project metadata forms the header section that gives readers context before they see the technical details.

Think of project metadata as the cover page of your architecture document — it should give any reviewer enough context to understand what they're looking at and why it matters.

## Core Info

### Project Name

The display name of your project, shown in the window title bar, exported reports, and version snapshots. Choose a name that clearly identifies the system's purpose — "Customer Support Automation" is better than "Project Alpha". If your organisation has naming conventions for technology projects, follow those here. The name appears in the title bar alongside a dot indicator when there are unsaved changes.

### Description

A summary of what the agentic system does — its purpose, scope, and key capabilities. This is a multi-line text field designed for a paragraph or two. Write this for someone encountering the project for the first time: what problem does it solve, who are the users, and what are the main workflows? A good description might read: "Automated customer support system that handles billing inquiries, account changes, and technical troubleshooting. Routes complex cases to human agents. Serves approximately 50,000 monthly active users across web chat and email channels." This appears at the top of exported reports and helps reviewers quickly understand the system's scope.

### Business Justification

Why this system is being built — the business case. This is distinct from the Description (what it does) and documents the reasoning behind the investment. Include the problem being solved, the expected benefits, and any quantified value if available. For example: "Manual ticket processing costs \$2.3M/year with average 4-hour resolution time. This system targets 70% automated resolution with sub-5-minute response time, projected to save \$1.6M annually and improve customer satisfaction scores by 15 points." During architecture reviews, the justification helps reviewers assess whether the technical complexity is proportionate to the business value.

### Target Completion

The expected delivery or go-live date (e.g. "2026-06-30", "Q3 2026", "End of Sprint 14"). This establishes the timeline context for the architecture. A system going live next month has very different architectural constraints than one planned for next year — the former needs to prioritise simplicity and proven patterns, while the latter can explore more ambitious approaches. The target date also appears in exported reports and helps stakeholders track project timelines.

### Estimated Effort

How much work the project is expected to take (e.g. "40 person-days", "3 sprints", "2 months with 4 engineers", "320 story points"). This complements the target date by giving a sense of the project's scale. During architecture reviews, effort estimates help reviewers calibrate their expectations — a 2-week proof-of-concept should have a simpler architecture than a 6-month production build. If the effort seems disproportionate to the architecture's complexity (or vice versa), that's a useful signal.

### Team Size

The number of concurrent users the system needs to support (e.g. "5", "100", "10000"). This is one of the most impactful project metadata fields because the [Sizing](sizing.md) estimator uses it directly to scale infrastructure recommendations. The base sizing calculations assume 100 users; if you set Team Size to 500, vCPU and RAM estimates are scaled up proportionally. If Team Size to 20, they scale down.

Be clear about what "users" means for your system. For a customer-facing chatbot, it's the number of concurrent end users. For an internal automation tool, it might be the number of employees who use it simultaneously during business hours. For an event-driven system, think about peak concurrent sessions rather than total registered users.

## Technical Scope

### Agents (read-only)

The number of agent nodes in your graph. This is calculated automatically and displayed for quick reference. Combined with the tool count, it determines which [Sizing](sizing.md) tier your system falls into (Simple, Medium, or Hard).

### Data Sources (read-only)

The number of knowledge nodes in your graph. Displayed automatically for reference. A high data source count relative to agent count may indicate a knowledge-heavy architecture that needs strong retrieval infrastructure.

### Tools (read-only)

The number of tool nodes in your graph. Displayed automatically. High tool diversity (many different tool types and categories) increases infrastructure complexity because each tool type may need its own runtime environment, authentication mechanism, and monitoring.

### Integration Points

The external systems your architecture connects to (e.g. "Salesforce, SAP, Slack, internal CRM API, payment gateway"). This documents the integration surface area of your system. Each integration point is a potential failure point, a security boundary, and a dependency that needs to be managed. During architecture reviews, reviewers check that each listed integration point has a corresponding tool node in the graph with appropriate error handling and authentication. A long list of integration points with few tool nodes suggests the graph is incomplete; tool nodes with no corresponding integration point listed here suggest undocumented dependencies.

### Deployment Target

Where the system will run. This affects the [Sizing](sizing.md) estimator's architecture decomposition and infrastructure recommendations:

- **Cloud** — Deployed on a public cloud platform (AWS, Azure, GCP, IBM Cloud). This is the most common choice and typically the simplest to scale. The Sizing estimator assumes elastic scaling and managed services are available.
- **On-Premises** — Deployed in your organisation's own data centre. This introduces capacity planning constraints — you can't just spin up more instances on demand. On-prem deployments also need to consider hardware procurement lead times. The Sizing estimator flags this as a consideration in scaling recommendations.
- **Hybrid** — Some components run in the cloud, others on-premises. Common when sensitive data must stay on-prem but compute-intensive inference can use cloud resources. This is the most complex deployment model because it requires network connectivity, security boundaries, and data transfer management between environments.

## Risk & Compliance

### Overall Risk Level

The project-wide risk assessment (None, Low, Medium, High). This is distinct from the per-node risk levels on individual agents, tools, and knowledge sources — it represents the aggregate risk of the entire system. The [Analysis](analysis.md) engine checks this against your graph's characteristics. A project marked "Low" risk but containing agents that modify financial records and handle PII will generate a warning about the mismatch.

When setting this, consider the worst-case scenario: what happens if the system makes a wrong decision, exposes data it shouldn't, or goes down entirely? If the answer is "minor inconvenience", it's Low. If it's "regulatory fine, data breach, or significant financial loss", it's High. Be honest rather than optimistic — underestimating risk leads to under-investment in guardrails and monitoring.

### Compliance Requirements

The regulatory frameworks and standards that apply to your system (e.g. "GDPR, SOC2", "HIPAA, HITRUST", "PCI-DSS", "ISO 27001", "FCA regulations", "None"). This field is checked by the Analysis engine's security patterns — if you list compliance requirements but your graph lacks audit logging, data encryption tools, or access controls, Analysis will flag the gaps.

Even if no formal regulation applies, consider industry standards and internal policies. Many organisations have data handling requirements that aren't legally mandated but are contractually obligated (e.g. customer agreements, partner SLAs). List everything that constrains how your system handles data and makes decisions.

### Data Classification

The highest sensitivity level of data flowing through the system (e.g. "Public", "Internal", "Confidential", "Restricted", "PII", "PHI"). This should reflect the most sensitive data handled anywhere in the graph, not just the average. If 90% of your data is public but one knowledge source contains PII, the classification should reflect that PII is present.

Data classification affects architectural decisions at every level: where data can be stored, who can access it, whether it can cross network boundaries, how it must be encrypted, and how long it can be retained. The Analysis engine uses this field to verify that your graph has appropriate data protection measures. A "Confidential" classification with no security or guardrail tools is a significant finding.

### Regulatory Constraints

Specific regulatory limitations that constrain the architecture (e.g. "Financial services regulations prohibit fully automated lending decisions", "Healthcare data must remain within EU borders", "AI-generated content must be labelled as such", "Human approval required for decisions over \$10,000"). While Compliance Requirements lists the frameworks, this field documents the specific constraints those frameworks impose on your design.

These constraints often drive architectural patterns: a requirement for human approval means you need a human-in-the-loop workflow; data residency requirements affect deployment target and may force on-premises components; auditability requirements demand comprehensive logging and observability. Document the constraints here so reviewers can verify the architecture satisfies them.

## Dependencies & Blockers

### Critical Dependencies

External systems, teams, services, or decisions that your project depends on (multi-line text). These are things outside your control that must be in place for the system to work. Examples: "Customer identity service must support OAuth 2.0 token exchange by launch date", "Data engineering team needs to deliver the product catalog ETL pipeline", "Legal must approve the AI usage policy before we can deploy to customers", "The new Kubernetes cluster must be provisioned in the staging environment".

Document dependencies explicitly because they are the most common source of project delays and architectural compromises. Each dependency is a risk — if it slips or changes, your architecture may need to adapt. During reviews, these help identify what assumptions the architecture is built on and what happens if those assumptions break.

### Key Assumptions

Design assumptions that the architecture relies on (multi-line text). These are things you believe to be true but haven't fully verified. Examples: "Average conversation length will be under 10 turns", "The LLM can accurately classify customer intent with \>90% accuracy", "Peak load will not exceed 500 concurrent users", "Tool response times will be under 2 seconds", "Users will accept AI-generated responses for routine inquiries".

Assumptions are risks in disguise. If an assumption turns out to be wrong, the architecture may need significant changes. By documenting them explicitly, you create a checklist for validation — each assumption should eventually be either confirmed through testing or invalidated and addressed. During architecture reviews, reviewers specifically look for untested assumptions that could undermine the design.

### Open Questions / Blockers

Unresolved questions or active blockers that may affect the architecture (multi-line text). Examples: "Which LLM provider will we use in production?", "How will we handle multi-language support — translation tool or multilingual model?", "What is the approved data retention period for conversation logs?", "Waiting on security review of the MCP server implementation", "Need to decide between synchronous and asynchronous tool execution for the payment flow".

Open questions represent genuine uncertainty in your design. They're different from assumptions (which you've made a decision on, even if unvalidated) — these are decisions that haven't been made yet. Documenting them keeps them visible and prevents the architecture from silently proceeding with an implicit default that nobody agreed to. Review these regularly and resolve them as the project progresses. Exported reports include open questions, making them visible to stakeholders.

## See Also

- [Inspector](inspector.md)
- [Sizing](sizing.md)
- [Analysis](analysis.md)
- [Files & Export](file-operations.md)
