# The Canvas

The canvas is an infinite two-dimensional surface where you build your graph. It supports panning, zooming, and various selection and arrangement tools.

## Navigation

| Action      | How                                                 |
|-------------|-----------------------------------------------------|
| Pan         | Two-finger scroll on a trackpad                     |
| Zoom        | Pinch on a trackpad, or the scroll wheel on a mouse |
| Zoom to fit | Use the zoom bar at the bottom of the canvas        |

The zoom bar in the bottom-left corner displays the current zoom percentage and provides four controls:

- **Zoom out (−)** — Decreases the zoom level one step.
- **Zoom percentage** — Shows the current zoom level as a percentage.
- **Zoom in (+)** — Increases the zoom level one step.
- **Fit to content** — Adjusts zoom and scroll so the entire graph fits in the visible area.
- **Lock toggle** — When locked, trackpad pinch and scroll-wheel zoom are disabled so you can scroll the canvas without accidentally changing the zoom level. The zoom in/out buttons still work when locked.

## Node Type Visibility

Each node type in the sidebar palette has an eye icon toggle. Click it to hide or show all nodes of that type on the canvas. Hidden nodes are not deleted — they are simply not rendered, making it easier to focus on a specific part of your architecture. For example, you might hide all shape and comment nodes to see just the functional components, or hide tools to focus on agent-to-agent delegation paths. Hidden node types have a slashed-eye icon in the sidebar. Edges connected to hidden nodes are also hidden.

## Adding Nodes

Drag a node type from the sidebar palette and drop it onto the canvas. The node appears at the drop position with default settings.

## Selecting

- **Click** a node or edge to select it.
- **Click empty canvas** to deselect everything.
- **Marquee select** — click and drag on an empty area of the canvas to draw a selection rectangle. All nodes within the rectangle are selected.
- **Shift-click** to add or remove individual nodes from a multi-selection.

## Moving and resizing

- **Drag** a selected node to move it. If multiple nodes are selected, they all move together.
- **Resize** by dragging the resize handle at the bottom-right corner of a node.

## Connecting nodes

1.  Hover over a port dot on a component node — the port highlights.
2.  Click and drag from the port toward another node.
3.  Release on a compatible port to create an edge.

Edges are drawn as bezier curves with optional arrowheads. You can customise the colour and line style of each edge in the Inspector.

## Arranging

The **Arrange** menu provides alignment and distribution tools for multi-selected nodes:

- **Align Left** (<kbd>⌘</kbd><kbd>⌥</kbd><kbd>\[</kbd>) — Align selected nodes to their leftmost edge.
- **Align Right** (<kbd>⌘</kbd><kbd>⌥</kbd><kbd>\]</kbd>) — Align selected nodes to their rightmost edge.
- **Align Top / Bottom / Centre Horizontally / Centre Vertically** — Additional alignment options.
- **Distribute Horizontally / Vertically** — Space selected nodes evenly.

## Grouping

Select multiple nodes and choose **Arrange \> Group** (<kbd>⌘</kbd><kbd>G</kbd>) to group them. Grouped nodes move and resize as a unit. Use **Ungroup** (<kbd>⌘</kbd><kbd>⇧</kbd><kbd>G</kbd>) to separate them.

## Copy, Cut, and Paste

Use the standard <kbd>⌘</kbd><kbd>C</kbd> and <kbd>⌘</kbd><kbd>V</kbd> to copy and paste selected nodes. Pasted nodes appear offset from the originals. <kbd>⌘</kbd><kbd>X</kbd> (Cut) copies the selected nodes and then deletes them from the canvas in one step. <kbd>⌘</kbd><kbd>A</kbd> selects all nodes on the canvas.

## Undo and Redo

Most canvas operations support undo (<kbd>⌘</kbd><kbd>Z</kbd>) and redo (<kbd>⌘</kbd><kbd>⇧</kbd><kbd>Z</kbd>). This includes adding and deleting nodes, moving and resizing nodes, creating and removing edges, editing node and edge properties, and paste operations. The undo stack is per-window and persists as long as the window is open.

## Shape Z-Order

Shape nodes (rectangles, rounded rectangles, ovals, and text) can be layered in front of or behind other shapes. When a shape is selected, the inspector shows four z-order buttons:

- **Forward** — Moves the shape one layer up.
- **Backward** — Moves the shape one layer down.
- **To Front** — Moves the shape to the very front, above all other shapes.
- **To Back** — Moves the shape to the very back, behind all other shapes.

Z-order only affects the stacking of shape nodes relative to each other. Component nodes (agents, tools, knowledge, humans) always render above shapes.

## Dark Mode

Each window has its own light/dark mode setting, toggled via the toolbar. This is independent of the system appearance.

## See Also

- [Node Types](node-types.md)
- [Inspector](inspector.md)
- [Keyboard Shortcuts](keyboard-shortcuts.md)
