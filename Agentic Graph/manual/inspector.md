# Inspector

The Inspector is the right sidebar of the main window. It has six tabs, selected via a segmented control at the top: Properties, Comments, Analysis, Sizing, Load Simulation, and Prompt Analysis.

> **Tip:** Toggle the inspector sidebar visibility using the toolbar button or **View \> Inspector** in the menu bar.

## Properties Tab

The Properties tab adapts its content based on what is selected on the canvas.

### Nothing Selected — Project View

When nothing is selected, the Properties tab shows the [project metadata](project-metadata.md) form (name, description, risk level, team size, etc.). Below the metadata fields, two additional sections appear:

#### Orphans

The Orphans disclosure group lists all component nodes (agents, tools, knowledge sources, and humans) that have no connections to any other node. Orphan nodes often indicate incomplete modelling — an agent with no tools, a knowledge source nobody queries, or a human participant not wired into any workflow. Each orphan appears as a clickable chip: click it to select the node and pan the canvas to it, making it easy to find and connect stray nodes. The orphan count is shown in the section header.

#### Versions

The Versions disclosure group shows recent [version snapshots](file-operations.md) inline in the inspector, giving you quick access to your project history without opening the full Version History sheet. Each entry shows the version name and date.

### Single Node Selected

Shows the node's title, appearance settings (banner colour, font size, font colour), and type-specific metadata fields. For example, an Agent node shows framework, model, complexity, role, goals, and more. See the individual node reference pages for full field documentation: [Agent](node-agent.md), [Tool](node-tool.md), [Knowledge](node-knowledge.md), [Human](node-human.md).

#### Ports

Component nodes (agents, tools, knowledge sources, and humans) have a Ports section in the inspector where you can manage their input and output ports. Each port appears as a row with its label. You can:

- **Add a port** — Click the **+** button to add a new custom-labelled input or output port.
- **Remove a port** — Click the delete button on a port row to remove it. Any edges connected to that port are also removed.
- **Reorder ports** — Drag port rows up and down to change the order in which they appear on the node.

#### Connections

Below the node's metadata fields, a Connections disclosure group lists every edge connected to the selected node. Each connection shows the names of the two endpoints. Click the arrow button on a connection to select that edge (useful for editing its colour or line style). Click the delete button to remove the connection. The connection count is shown in the section header.

### Single Edge Selected

Shows the edge's appearance settings and the nodes it connects:

- **Colour** — The edge's stroke colour. A colour picker lets you change it, and a "Reset to Default" button restores the standard colour.
- **Line style** — Solid, dashed, or dotted.
- **Connected nodes** — Shows the source and target node names.
- **Select Connected Nodes** — A button that selects both endpoint nodes, which is useful when you want to inspect or move the nodes on either side of an edge.
- **Delete Connection** — Removes the edge from the graph.

### Multiple Nodes Selected

A multi-select inspector that lets you batch-edit shared properties like colour, font size, and common metadata fields across all selected nodes. Only fields that are common to all selected node types are shown.

## Comments Tab

The Comments tab holds free-form notes that travel with your project but stay out of the structured metadata fields. Like the Properties tab, it is context-sensitive:

- **A node selected** — Edit a comment attached to that node.
- **An edge selected** — Edit a comment attached to that connection.
- **Nothing selected** — Edit a project-level comment.

With two or more objects selected, the tab asks you to narrow the selection to a single node, edge, or the project. Drag the handle below the editor to resize it. Comments are saved inside the `.ag` file and are included in exported [HTML reports and Markdown documentation](file-operations.md), which makes them a good place for review notes, open questions, or design rationale you want collaborators and stakeholders to see.

## Analysis Tab

Displays results from the AI-assisted architecture analysis. Shows a summary bar (warnings, recommendations, positives, info), severity filters, and individual finding cards grouped by category. See [Analysis](analysis.md) for details.

## Sizing Tab

Shows infrastructure sizing estimates calculated from the graph structure. Includes workload profile, resource recommendations, architecture decomposition, scaling recommendations, and caching assessment. See [Sizing](sizing.md) for details.

## Load Simulation Tab

The Load Simulation tab estimates how long a selected agent takes to respond, showing a typical and a p95 (worst-case) figure with a breakdown of where the time goes. It is a pure calculation — no LLM is needed. The tab is active only when one Agent node is selected. This is a beta feature; see [Load Simulation](load-simulation.md) for full details.

## Prompt Analysis Tab

The Prompt Analysis tab uses AI to review a single agent's prompt for clarity, scope, and routing problems. It is active only when one Agent node is selected. See [Prompt Analysis](prompt-analysis.md) for full details.

## Node Chips

In the Analysis and Sizing tabs, related nodes appear as clickable chips coloured by node type. Click a chip to select the node and pan the canvas to it. Double-click a chip to also switch to the Properties tab so you can immediately edit the node's fields.

## See Also

- [Analysis](analysis.md)
- [Prompt Analysis](prompt-analysis.md)
- [Sizing](sizing.md)
- [Load Simulation](load-simulation.md)
- [Project Metadata](project-metadata.md)
