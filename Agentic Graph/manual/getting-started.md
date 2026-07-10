# Getting Started

Agentic Graph is a visual editor for designing agentic AI system architectures. You build graphs by placing nodes on a canvas and connecting them with edges to model how agents, tools, knowledge sources, and humans interact.

## The workspace

The main window has three columns:

- **Sidebar palette** (left) — Draggable node types organised into Components, Annotations, and Shapes. A Settings button at the bottom opens the preferences view.
- **Canvas** (centre) — An infinite pannable, zoomable surface where you build your graph.
- **Inspector** (right) — Tabs for Properties, Comments, Analysis, Sizing, and Prompt Analysis. Shows details for the selected node, edge, or the project as a whole.

## Create a new project

1.  Choose **File \> New** (<kbd>⌘</kbd><kbd>N</kbd>) to open a blank canvas, or **File \> New Window** (<kbd>⌘</kbd><kbd>⇧</kbd><kbd>N</kbd>) to open an additional window.
2.  Drag a node from the sidebar palette onto the canvas. Start with an **Agent** node — the core building block of any agentic system.
3.  Add **Tool** and **Knowledge** nodes to represent the capabilities and data sources your agents will use.
4.  Connect nodes by dragging from one port dot to another. Edges represent the flow of information or delegation between components.

## Save your work

Press <kbd>⌘</kbd><kbd>S</kbd> to save. Projects are saved as `.ag` files — a portable format you can share with others. The title bar shows a dot indicator when there are unsaved changes.

> **Tip:** Open an existing project with <kbd>⌘</kbd><kbd>O</kbd>, or drag an `.ag` file onto the Dock icon.

## Next steps

Once you have a basic graph, try:

- Selecting a node and filling in its metadata in the [Inspector](inspector.md).
- Running an [Architecture Analysis](analysis.md) to find patterns and anti-patterns.
- Reviewing an agent's instructions with [Prompt Analysis](prompt-analysis.md).
- Checking the [Sizing](sizing.md) tab for infrastructure estimates.
- Adding [project metadata](project-metadata.md) like risk level, team size, and deployment target.

## See Also

- [Node Types](node-types.md)
- [The Canvas](canvas.md)
- [Keyboard Shortcuts](keyboard-shortcuts.md)
