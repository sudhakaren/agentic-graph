# Files & Export

## The .ag file format

Projects are saved as `.ag` files — ZIP archives containing a JSON graph definition, an optional preview image, and version snapshots. You can share `.ag` files with anyone who has Agentic Graph installed.

## Saving

| Action | Shortcut |
|----|----|
| Save | <kbd>⌘</kbd><kbd>S</kbd> |
| Save As | <kbd>⌘</kbd><kbd>⇧</kbd><kbd>S</kbd> |

The title bar shows a dot indicator when there are unsaved changes. On close, you are prompted to save if there are unsaved modifications.

## Opening

| Action      | Shortcut                                             |
|-------------|------------------------------------------------------|
| Open        | <kbd>⌘</kbd><kbd>O</kbd> |
| Open Recent | File \> Open Recent                                  |

You can also drag an `.ag` file onto the Dock icon or onto a blank canvas window to open it. If the file is already open in another window, that window is brought to the front instead of opening a duplicate.

When you open a file while a blank, untitled window exists (no nodes, no file, no unsaved changes), the file loads into that window rather than creating a new one. This keeps your workspace tidy when opening files from the Finder or the Open Recent menu.

## Export

Export options are available from the **File \> Export** submenu and from the toolbar when the relevant inspector tab is active:

- **PNG** — Exports the visible graph as a high-resolution image.
- **Analysis Report (HTML)** — Exports the analysis findings as a standalone HTML report. Also available from the toolbar when the Analysis tab is active.
- **Analysis Report (Markdown)** — Exports the analysis findings as a Markdown file, suitable for pasting into wikis, READMEs, or documentation systems.
- **Sizing Report (HTML)** — Exports the sizing estimates as a standalone HTML report. Available from the toolbar when the Sizing tab is active.
- **Sizing Report (Markdown)** — Exports the sizing estimates as a Markdown file.
- **Markdown Documentation (ZIP)** — Exports a complete project documentation package as a ZIP archive. This includes the project metadata, all node and edge definitions, analysis findings, and sizing estimates — everything in your project as structured Markdown files. Use this for archiving, sharing with stakeholders who don't have Agentic Graph, or feeding into other documentation pipelines.
- **Analysis Patterns (JSON)** — Exports the current analysis pattern library to a JSON file for sharing with teammates or backing up custom patterns. Also available from Settings \> Analysis \> Patterns.

## Import

### Framework projects

The **File \> Import** menu can read a project written for a popular agent framework and turn it into a graph. Choose the importer, pick the project's folder, and Agentic Graph scans it for agents, tools, and knowledge sources and lays them out as connected nodes:

- **watsonx Orchestrate Project** (<kbd>⌘</kbd><kbd>⇧</kbd><kbd>I</kbd>) — IBM watsonx Orchestrate ADK projects: native agent YAML specs, Python `@tool` functions, OpenAPI tool specs, and knowledge bases.
- **CrewAI Project** — CrewAI crews: the `agents.yaml` and `tasks.yaml` configuration plus tool definitions.
- **LangGraph Project** — LangGraph applications: the `langgraph.json` manifest and the graph's nodes and edges.
- **OpenAI Agents SDK Project** — Projects built on the OpenAI Agents SDK: `Agent` definitions, their tools, and handoffs.
- **AutoGen / AG2 Project** — AutoGen / AG2 scripts: assistant and user-proxy agents, group chats, and registered tools.

An imported graph is a starting point — review the generated nodes and fill in any metadata the source project doesn't capture. Each import also adds an "Imported" version snapshot, so the pristine import stays available to compare against as you edit.

### Analysis patterns

- **Analysis Patterns (Replace)** — Import pattern definitions from a JSON file, replacing the entire current pattern library. Use this when adopting a team-standard pattern set. Available from the File \> Import menu and from Settings \> Analysis \> Patterns.
- **Analysis Patterns (Merge)** — Import pattern definitions from a JSON file, adding new patterns while keeping existing ones. Use this to augment your library without losing customisations. Available from the File \> Import menu and from Settings \> Analysis \> Patterns.

## Merge

Where **Import** turns an external project into a new graph, **Merge** brings one into the graph you already have open, updating it in place. The **File \> Merge** submenu offers two kinds.

### Merge a watsonx Orchestrate project

Re-imports a watsonx Orchestrate project folder and reconciles it against the current graph. Each agent, tool, and knowledge source is matched to the node a previous import produced for it: matched nodes have their imported fields refreshed, nodes for newly-added source items are created, and nodes whose source artifact has been removed are deleted. Connections within the imported subgraph are re-derived from the source, while any you drew yourself are preserved. Use this to pull source-side changes into a graph you have already annotated, without losing your own edits, layout, or comments.

### Merge an Agentic Graph project

Combines another `.ag` file into the current graph, matching nodes and edges by identity. Items the two files share are refreshed from the merged file; items only in the merged file are added below the existing graph; items only in the current graph are kept. When the two files are related — a branched copy — nodes that are absent from the merged file are left in place and selected, so you can review them. Use this to compose a graph from separately-built pieces, or to fold a branched copy back together.

Every merge writes a version snapshot before it starts and another when it finishes, so you can compare the before and after states — or revert — from the Version History sheet. A summary then reports how many nodes were updated, added, and removed.

## Version snapshots

Create named snapshots of your project at key milestones:

| Action | Shortcut |
|----|----|
| Create Version | <kbd>⌘</kbd><kbd>⌥</kbd><kbd>S</kbd> |
| Version History | File \> Versions |

Each version stores a complete snapshot of the graph. Versions are saved inside the `.ag` file.

The **Version History** sheet lists every saved version. Each row offers three actions:

- **Open as Copy** — Opens the snapshot in a new window as a detached, editable copy (see below).
- **Revert** — Replaces the current graph with the snapshot. This is undoable.
- **Delete** — Removes the snapshot from the project.

### Opening a version as a copy

Choosing **Open as Copy** on a version opens that snapshot in its own window as a new, untitled document. You can explore and edit it freely — it is a separate working copy, so your changes never affect the project you opened it from, nor the stored version. To keep the copy, use **Save As** (<kbd>⌘</kbd><kbd>⇧</kbd><kbd>S</kbd>) to write it to a new `.ag` file; closing the window without saving discards it.

## Session restore

Unsaved work is automatically preserved across app launches. If the app is quit with unsaved changes, they are restored when you next open the app.

## See Also

- [Getting Started](getting-started.md)
- [Analysis](analysis.md)
- [Sizing](sizing.md)
