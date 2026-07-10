# Human Node

A Human node represents a person who interacts with the agentic system — a customer submitting requests, an administrator approving actions, an analyst reviewing outputs, or any other human participant. Humans are a critical part of most agentic architectures because they provide the oversight, judgement, and real-world context that agents lack.

Human nodes have both input and output ports, modelling the two-way nature of human-agent interaction. Information flows in (notifications, questions, reports for review) and decisions flow out (approvals, corrections, new instructions). In human-in-the-loop architectures, the human node is often the control point where automated processes pause for human judgement before proceeding with high-stakes actions.

## Node Fields

### Title

The display name or role label for this human participant, shown on the canvas and referenced in analysis findings. Use a name that identifies the human's role in the system rather than a specific person — "Customer", "Compliance Officer", "Support Agent", "System Administrator" — since the graph documents the architecture, not the org chart. If multiple types of humans interact with the system, create separate nodes for each role.

### Risk

The risk level associated with this human's interactions and authority. A customer browsing a catalog is Low risk; an administrator who can approve financial transactions or override system decisions is High risk. Consider what damage could occur if this human's credentials were compromised or if they made incorrect decisions — that's your risk level. Values: None, Low, Medium, High.

## Human Fields

### Input Channel

How the human sends information to the system — the communication path from human to agent. This field has a significant impact on the [Sizing](sizing.md) estimator's interaction pattern calculation:

- **None** — No input channel specified.
- **Chat** — Real-time conversational interface (web chat, messaging app). Implies low-latency requirements — users expect responses within seconds. The Sizing estimator classifies this as a "Conversational" interaction pattern with a P95 latency target under 5 seconds.
- **Portal** — A web application or dashboard where the human submits forms, uploads documents, or triggers actions. Similar to Chat in implying interactive use, but typically with slightly more tolerance for processing time. Also classified as "Conversational" by Sizing.
- **Email** — Asynchronous communication. The human sends an email and expects a response within hours, not seconds. The Sizing estimator classifies this as "Task Execution" with much looser latency requirements.
- **Phone** — Voice interaction, either directly with the system (IVR, voice agent) or mediated by a human support agent who uses the system. Implies real-time requirements similar to Chat.
- **API** — The human interacts programmatically, perhaps through a script or CLI tool. Implies technical users who are comfortable with structured interfaces.
- **SMS** — Text message interaction. Asynchronous like email but with shorter message formats and mobile-first expectations.
- **Custom** — For channels not listed above (e.g. Slack, Teams, in-app notifications).

### Output Channel

How the system sends information back to the human. This can differ from the input channel — a common pattern is for humans to submit requests via a Portal but receive notifications via Email or SMS. The output channel determines what kind of response formatting the system needs (rich HTML for email, concise text for SMS, structured data for API). If the input and output channels are the same (e.g. Chat/Chat), the interaction is synchronous and conversational. If they differ (e.g. Portal input, Email output), there's an implied asynchronous handoff that needs to be designed. Same options as Input Channel.

### Role

The human's role within the system (e.g. "Customer", "Admin", "Analyst", "Approver", "Auditor"). While the Title identifies the human on the canvas, the Role field provides more detail about their function. This is particularly important for access control design and compliance — different roles should have different permission levels. During architecture reviews, reviewers check that the role is consistent with the Access Level and that appropriate guardrails exist for privileged roles.

### Language

The language(s) this human communicates in (e.g. "English", "Spanish", "English, Mandarin", "Multi-language"). This affects your agent architecture in several ways: agents interacting with non-English speakers need multilingual capabilities (either multilingual models or translation tools), content in knowledge sources may need to be available in multiple languages, and response formatting may need to handle different character sets and text directions. If your system serves a global user base, documenting language requirements per human type helps identify where translation or localisation tools are needed.

### Timezone

The human's timezone or timezone range (e.g. "UTC", "EST", "GMT+1", "US timezones", "Global"). Timezone information affects the [Sizing](sizing.md) estimator's consistency assessment — humans spread across multiple timezones suggest 24/7 load patterns rather than business-hours-only usage. This has direct infrastructure implications: a business-hours system can scale down at night, but a global system needs consistent capacity around the clock. Timezone also matters for SLA calculations, notification timing, and scheduling.

### Auth Method

How the human authenticates with the system (e.g. "SSO", "MFA", "Username/Password", "API Key", "Biometric", "Certificate"). This documents the security model for human access. Strong authentication (MFA, SSO with conditional access) is especially important for humans with high access levels or those who can approve critical actions. The [Analysis](analysis.md) engine considers authentication as part of its security evaluation — a human with Admin access and weak authentication is a security risk.

### Access Level

What the human is authorised to do within the system (e.g. "Read-only", "Standard user", "Full access", "Admin", "Super admin"). This is a governance field that defines the permission boundary. Access levels should follow the principle of least privilege — each human type should have the minimum permissions needed for their role. During architecture reviews, reviewers check that high access levels are paired with appropriate authentication, audit logging, and oversight. A "Full access" human with no audit trail is a compliance gap.

### SLA / Response

The expected response time for this human when the system needs their input (e.g. "Real-time", "Within 15 minutes", "4 hours", "Next business day"). This is critical for workflows that include human approval or review steps. If an agent needs human approval before executing a high-risk action, the human's SLA determines how long that action is delayed. A 4-hour SLA on a human approver in a real-time customer-facing workflow creates a significant bottleneck. Document this honestly based on actual availability, not aspirational targets — the architecture needs to handle the real delays, not the ideal ones.

### Expected Behaviors

What actions this human typically performs in the system (e.g. "Submits support tickets, rates agent responses", "Reviews and approves loan applications", "Escalates complex cases, provides feedback on agent quality"). This documents the human's responsibilities in the workflow and helps reviewers verify that the graph supports all the interactions this human needs. If the expected behaviours include "approves financial transactions" but there's no approval tool or guardrail in the graph, that's a design gap. Think of this as the human's "job description" within your agentic system.

## Details

### Detail

Free-text notes for additional context. Use this for escalation procedures ("If unresponsive for \>2 hours, the system auto-escalates to the team lead"), shift patterns ("Available Monday-Friday, 9am-5pm EST; weekend coverage via on-call rotation"), training requirements ("Must complete the AI oversight training before being granted approval authority"), workflow specifics ("Reviews are batched and processed at 10am and 3pm daily"), or links to operational runbooks.

## Ports

Human nodes have both input and output ports. Input ports represent information flowing to the human — notifications, reports, requests for approval, agent outputs that need review. Output ports represent actions or decisions flowing from the human back into the system — approvals, corrections, new instructions, feedback. You can add custom-labelled ports to make the interaction model explicit, such as an "Approval Request" input and an "Approved/Rejected" output.

## Appearance

### Banner Color

The colour of the node's header banner on the canvas. Defaults to the standard human colour (green). You might customise this to distinguish between different types of human participants — for example, external customers in one colour and internal staff in another.

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
- [Knowledge Node](node-knowledge.md)
