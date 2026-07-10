# Prompt Analysis

Prompt Analysis uses AI to review the instructions you give an agent. Where the [Analysis](analysis.md) tab evaluates the whole graph's structure, Prompt Analysis focuses on a single agent's prompt text — checking it for ambiguity, missing constraints, scope creep, and routing problems.

> **Note:** Prompt Analysis is AI-assisted. Findings should be verified by a qualified reviewer.

Open it from the **Prompt Analysis** tab in the [Inspector](inspector.md) — the magnifying-glass icon at the right-hand end of the tab bar. The tab works only when a single [Agent](node-agent.md) node is selected; with anything else selected it asks you to select an agent.

## The prompt field

The large text field at the top holds the prompt to analyse. You can type or paste into it directly, or fill it from the selected agent:

- **Copy from agent** — Copies the selected agent's Instructions field into the prompt field.
- **Chain** — Concatenates the linear chain of upstream agents that feed into this one, so you can review a hand-off as a whole. The button is enabled only when the agent has exactly one upstream agent caller; with none or several, chaining would be ambiguous and the button is disabled.

If the prompt field already holds text that doesn't match, Copy from agent and Chain ask for confirmation before replacing it. The prompt text is saved with the project, separately for each agent, so your drafts survive closing and reopening the file.

## Translation

When a target language is configured in [Settings \> Analysis \> Prompt Analysis](settings.md), a **To \<language\>** button appears next to the prompt field and translates the current prompt text into that language in place. An optional second "reverse" target adds a button that translates the other way — useful for round-tripping a prompt between two working languages. Each button is hidden when its language is left blank.

## Running an analysis

1.  Ensure an LLM provider is configured in [Settings \> Analysis \> LLM Provider](settings.md).
2.  Select an agent node and put the prompt to review in the prompt field.
3.  Optionally tick **Include routing details** (see below).
4.  Click **Analyse**. Click **Cancel** to stop a run in progress.

Results appear in a scrollable list below the controls. Each issue card shows a severity icon, a title, an explanation, and a recommended fix; use a card's chevron to collapse or expand its detail. When the prompt is clean, the list reports that no issues were found.

## Keeping a result

Two small icon buttons in the result header — beside the run time — save a completed analysis. Point at either to see what it does.

- **Append to Comments** — Adds the result to the selected agent's **Comments** field as a dated, plain-text block — a header line, then the title, issue, and recommendation for each finding. Running the analysis again appends a fresh block below the last, so the Comments field keeps a running history. The labels follow the app's language.
- **Copy to clipboard** — Copies the same block to the clipboard, ready to paste into a ticket, document, or message.

## Single agent vs. chain

A badge next to the Analyse button shows how the prompt will be interpreted:

- **Single agent** — The prompt is treated as one agent's instructions. This is the default, and what you get after Copy from agent.
- **Chain (N)** — The prompt is treated as a hand-off across N agents. This mode is set by the Chain button and lets the analysis reason about how the agents pass work along.

In either mode the analysis is also given context about the agents involved — their connected [tools](node-tool.md) and [knowledge sources](node-knowledge.md) — so it can judge whether the prompt matches the agent's actual capabilities.

## Include routing details

In a multi-agent system, an agent's **Details** field often doubles as its routing description — a short statement of what the agent does that upstream agents use to decide where to send a request. Tick **Include routing details** to feed each agent's Details field to the analysis as its routing description, so the review can check that the prompt and the routing description agree.

## Debugging the exchange

After a run, a small debug button (a bug icon) appears next to the controls. It opens a window showing exactly what was sent to and received from the LLM — the system prompt, the user message, and the raw response — which is useful when a result is surprising or when you are tuning the prompt templates in Settings.

## Settings

The system prompt and user-message template that drive the analysis are editable in [Settings \> Analysis \> Prompt Analysis](settings.md), along with the translation target languages. See [Settings](settings.md) for details.

## See Also

- [Inspector](inspector.md)
- [Analysis](analysis.md)
- [Settings](settings.md)
- [Agent Node](node-agent.md)
