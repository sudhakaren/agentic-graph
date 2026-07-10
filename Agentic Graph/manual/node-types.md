# Node Types

Nodes are the building blocks of your graph. They are organised into three categories in the sidebar palette.

## Components

Component nodes represent the functional parts of your agentic system. They have ports for creating connections. Click a node type below for a full field reference.

### [Agent](node-agent.md)

The core decision-making unit. Agents have both input and output ports and support rich metadata including framework, model, role, goals, complexity, memory type, delegation capability, latency budget, and iteration limits.

### [Tool](node-tool.md)

An external capability that agents can invoke. Tools have input and output ports. Metadata includes tool type (OpenAI, MCP, API, Python, etc.), endpoint, authentication method, category, error handling strategy, inputs, outputs, and async/sync behaviour.

### [Knowledge](node-knowledge.md)

A data source that agents can query. Knowledge nodes have an input port. Metadata covers location, data formats, access method, sensitivity, update frequency, size, retrieval and chunking strategies, and risk level.

### [Human](node-human.md)

Represents a human participant in the system. Humans have input and output ports. Metadata includes input/output channels, role, access level, SLA, timezone, and expected behaviours.

## Annotations

### Comment

A free-text annotation with no ports. Use comments to document design decisions, assumptions, or areas of concern directly on the canvas. Comments have a title (shown as the comment text), an optional detail field, and a configurable colour.

## Shapes

Visual-only elements for organising and decorating your graph. Shapes have no ports and cannot be connected.

### Rectangle / Rounded Rectangle / Oval

Geometric shapes for grouping related nodes visually or creating boundaries and regions on the canvas. Each has a line colour, optional fill colour, and z-order controls (bring forward, send backward).

### Text

A text label without a visible border. Useful for section headings or callouts. Has configurable font size and text colour.

## Ports and connections

Component nodes have small circular **ports** on their edges. Drag from one port to another to create an edge (connection). Edges represent data flow, delegation, or interaction between components.

- **Input ports** appear on the left side of a node.
- **Output ports** appear on the right side of a node.

You can connect any output port to any input port. The edge colour and line style can be customised in the [Inspector](inspector.md).

## Node defaults

Each node type has configurable default appearance settings (colour, size, font) in [Settings](settings.md) under the Components, Annotations, or Shapes sections.

## See Also

- [Agent Node Reference](node-agent.md)
- [Tool Node Reference](node-tool.md)
- [Knowledge Node Reference](node-knowledge.md)
- [Human Node Reference](node-human.md)
- [The Canvas](canvas.md)
- [Settings](settings.md)
