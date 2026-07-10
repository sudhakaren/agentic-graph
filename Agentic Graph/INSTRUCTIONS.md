# Building Agentic Graph from Scratch

This document explains how an AI coding assistant (or a developer) could recreate this application from the ground up. It covers the architecture, build order, design decisions, and gotchas encountered during development.

## Technology Stack

- **Language:** Swift 5.0 with Swift 6 concurrency defaults (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- **UI Framework:** SwiftUI (macOS)
- **Target:** macOS 26.2, sandboxed (`ENABLE_APP_SANDBOX = YES`)
- **Dependencies:** None. The app uses only system frameworks: SwiftUI, AppKit, Foundation, UniformTypeIdentifiers, and `zlib` (for CRC32 in the custom ZIP writer).

## Project Structure

```
Agentic Graph/
  Agentic_GraphApp.swift          -- @main entry point, WindowGroup, Settings scene, menu commands
  ContentView.swift               -- 3-column NavigationSplitView (sidebar, canvas, inspector)
  Info.plist                      -- UTType declarations, app category

  Model/
    NodeKind.swift                -- 8-case enum (agent, tool, knowledge, comment, 4 shapes)
    PortKind.swift                -- input/output enum + NodePort struct
    GraphNode.swift               -- Node struct with all metadata fields, enums, Color(hex:) extension
    GraphEdge.swift               -- Edge struct (source/target node+port IDs, colorHex, lineStyle)
    GraphDocument.swift           -- @Observable central state: nodes, edges, selection, canvas, undo, alignment, versions
    VersionSnapshot.swift         -- Version snapshot model (id, name, date, note, manifest)
    NodeDefaults.swift            -- Per-kind defaults model with UserDefaults persistence
    AGFileType.swift              -- UTType extension for .agenticGraph

  Views/
    CanvasView.swift              -- Canvas rendering + CanvasMouseHandler (NSViewRepresentable) + zoom bar
    NodeView.swift                -- Node rendering (standard, comment, shapes)
    NodePortView.swift            -- Port dot + label, position tracking via PreferenceKey
    EdgeLayerView.swift           -- SwiftUI Canvas for edge bezier rendering
    InspectorView.swift           -- Project settings + node/edge inspector with collapsible sections + versions
    MultiSelectInspectorView.swift -- Batch editor for multi-selected nodes/edges (field checkboxes + apply)
    SidebarPaletteView.swift      -- Draggable node palette
    FileMenuCommands.swift        -- File menu (New, Open, Recent, Save, Export, Create Version, Version History)
    ArrangeMenuCommands.swift     -- Arrange menu (alignment, distribution)
    SettingsView.swift            -- TabView with 8 tabs for node defaults
    NodeDefaultsTab.swift         -- Per-kind defaults form with binding helpers
    CreateVersionSheet.swift      -- Modal: version name + optional note + Create/Cancel
    VersionListSheet.swift        -- Full version history with Revert (confirmation) and Delete
    WindowAccessor.swift          -- NSWindowDelegate for dirty state + close confirmation
    PopoverColorPicker.swift      -- Color picker with hex presets + NSColorPanel

  Utilities/
    ZIPExporter.swift             -- ProjectManifest, ZIP export/import, HTML/Markdown generators, ZIPWriter/ZIPReader
    PNGExporter.swift             -- ImageRenderer-based PNG export (2x scale)
    DragTypes.swift               -- NodeKind: Transferable conformance
    EdgeGeometry.swift            -- Bezier sampling, segment intersection, hop-over arcs
    FocusedDocumentKey.swift      -- @FocusedValue keys for menu command callbacks
    RecentFilesManager.swift      -- Security-scoped bookmark tracking, recent files list
    SessionRestorer.swift         -- Last-session.json persistence + restore on launch
    PendingFileLoad.swift         -- Inter-window file load communication + blank-window reuse
    WxOImporter.swift             -- watsonx Orchestrate YAML project folder importer
```

## Recommended Build Order

Build the app incrementally. Each phase produces something runnable.

### Phase 1: Core Model

1. **NodeKind.swift** -- Define the 8-case enum with `displayName`, `sfSymbol`, `color`, `hasPorts`, `canHaveOutput`, `isShape`. Make it `String, Codable, CaseIterable, Identifiable`.

2. **PortKind.swift** -- Simple `input`/`output` enum. Define `NodePort` struct with `id: UUID`, `label: String`, `kind: PortKind`, `isAutoCreated: Bool`.

3. **GraphNode.swift** -- Start with basic fields: `id`, `kind`, `title`, `detail`, `position`, `size`, `ports`. Add `Codable` conformance. Add the `Color(hex:)` and `Color.hexString` extensions here -- you will use them everywhere.

4. **GraphEdge.swift** -- Simple struct: `id`, `sourceNodeID`, `sourcePortID`, `targetNodeID`, `targetPortID`, `colorHex`, `lineStyle` (solid/dashed/dotted). Uses backward-compatible decoding (`decodeIfPresent`) so old files without edge styling load correctly.

5. **GraphDocument.swift** -- `@Observable` class with `nodes: [GraphNode]`, `edges: [GraphEdge]`, `versions: [VersionSnapshot]`, `selectedNodeID`, `selectedNodeIDs`, `canvasOffset`, `canvasScale`. Add lookup helpers (`node(for:)`, `selectedNodeIndex`, `edges(connectedTo:)`). Version operations: `createVersion(name:note:)`, `revertToVersion(_:)`, `deleteVersion(id:)` — all with undo support.

### Phase 2: Basic Canvas + Sidebar

6. **DragTypes.swift** -- Make `NodeKind` conform to `Transferable` using `CodableRepresentation(contentType: .json)`.

7. **AGFileType.swift** -- Define `UTType.agenticGraph` and the drag content type. Register both in Info.plist.

8. **SidebarPaletteView.swift** -- Three sections (Agents, Annotations, Shapes) with `.draggable()` items.

9. **NodePortView.swift** -- Render port dots. Use a `PreferenceKey` (`PortPositionKey`) to report each port's screen position up to the canvas. This is how edge rendering knows where ports are.

10. **NodeView.swift** -- Render nodes by kind: `standardNode()` for agent/tool/knowledge (banner + port list), `commentView()`, `shapeView()`, `textShapeView()`.

11. **EdgeLayerView.swift** -- Use SwiftUI `Canvas` (the drawing primitive, not to be confused with the canvas view) to render edges as cubic bezier curves with arrowheads. Read port positions from the preference key.

12. **CanvasView.swift** -- This is the most complex view. It combines:
    - A background grid pattern
    - Shape layer (below everything)
    - Edge layer (middle)
    - Node layer (on top)
    - A zoom controls bar
    - A `.dropDestination()` for drag-from-sidebar
    - An `NSViewRepresentable` overlay for mouse handling (see Gotchas)

13. **ContentView.swift** -- `NavigationSplitView` with sidebar (palette), detail (canvas), and trailing sidebar (inspector).

14. **Agentic_GraphApp.swift** -- `@main` struct with `WindowGroup` and basic `.commands()`.

### Phase 3: Mouse Interaction (NSViewRepresentable)

15. **CanvasMouseHandler** (inside CanvasView.swift) -- This is `CanvasNSView: NSView` wrapped in an `NSViewRepresentable`. It handles:
    - `mouseDown` / `mouseDragged` / `mouseUp` -- node selection, dragging, edge creation, marquee selection, shape resizing
    - `rightMouseDown` / `rightMouseDragged` / `rightMouseUp` -- canvas panning + context menu
    - Hit testing for nodes and ports
    - Coordinate conversion between screen space and canvas space (accounting for zoom + pan)

### Phase 4: Persistence

16. **ZIPExporter.swift** -- Implement `ProjectManifest`, `ZIPWriter`, `ZIPReader`. The ZIP writer is a minimal implementation using `zlib.crc32()` for checksums, no compression (store method). Export and import `.ag` files.

17. **PNGExporter.swift** -- Use `ImageRenderer` with 2x scale. Render all visible elements into an offscreen view.

18. **FileMenuCommands.swift** -- File > New, Open, Save, Save As, Export submenu. Use `NSOpenPanel`/`NSSavePanel`.

19. **SessionRestorer.swift** -- Save canvas state + file bookmark (or manifest JSON for unsaved work) to Application Support on app termination. Restore on next launch.

20. **PendingFileLoad.swift** -- Singleton to pass loaded document data between windows (needed because Open creates a new window).

21. **RecentFilesManager.swift** -- Track up to 10 recent files with security-scoped bookmarks.

### Phase 5: Inspector + Undo

22. **InspectorView.swift** -- Build incrementally:
    - Project settings (name, then later all metadata sections)
    - Node inspector sections (title, risk, ports, connections, details)
    - Metadata sections per node type (agent, tool, knowledge)
    - Appearance controls

23. **PopoverColorPicker.swift** -- Color picker with 16 hex presets, manual hex entry, and NSColorPanel integration.

24. **WindowAccessor.swift** -- `NSWindowDelegate` for dirty state indicator and close confirmation dialog.

25. Add undo support to `GraphDocument` -- wrap mutations in `undoManager?.registerUndo()` calls.

### Phase 6: Polish Features

26. **EdgeGeometry.swift** -- Hop-over rendering when edges cross (detect intersections, draw arcs).

27. **ArrangeMenuCommands.swift** -- Alignment and distribution operations on multi-selected nodes.

28. **CanvasView right-click menu** -- `NSMenu` with Cut/Copy/Paste/Delete, Align, Distribute, Z-order.

29. **Copy/Paste** -- Internal clipboard with ID remapping and edge re-creation.

30. **SettingsView.swift** + **NodeDefaultsTab.swift** -- Settings window with 8 tabs for node defaults.

31. **NodeDefaults.swift** -- Per-kind defaults with UserDefaults JSON persistence.

32. **Project metadata** -- Add project-level fields to `GraphDocument` and `ProjectManifest`.

33. **HTML/Markdown generators** -- Rich export with project metadata, component details, embedded diagrams, colored node borders, risk/lock badges, edge styling (colors, line styles, port labels), and styled annotations.

### Phase 7: Version Snapshots

34. **VersionSnapshot.swift** -- `struct VersionSnapshot: Identifiable, Codable` with `id`, `name`, `createdAt`, `note`, `manifest: ProjectManifest`. Snapshots the full graph state.

35. **GraphDocument version operations** -- `createVersion(name:note:)`, `revertToVersion(_:)` (with undo via current-state capture), `deleteVersion(id:)`.

36. **ZIPExporter version persistence** -- On export, write each `VersionSnapshot` as `versions/{date}_{name}.json` inside the ZIP. On import, read and decode all entries in `versions/`. Old apps ignore unknown ZIP entries, so fully backward compatible.

37. **CreateVersionSheet.swift** -- Modal with name field (pre-filled with date), optional note, Create/Cancel.

38. **VersionListSheet.swift** -- Lists all versions newest-first with name, date, note, node/edge counts. Revert button with confirmation dialog, delete button. Both operations support undo.

39. **InspectorView versions section** -- Collapsible `DisclosureGroup` showing last 5 versions with count badge.

### Phase 8: Multi-Select Inspector + Node Locking

40. **MultiSelectInspectorView.swift** -- Batch editor that appears when 2+ items are selected. Filter toggles for node types and edges, per-field checkboxes, Apply button. Lock state changes bypass the "details locked" filter so you can unlock locked nodes.

41. **Node locking** -- 4 lock states: unlocked, positionLocked, detailsLocked, fullyLocked. Inspector enforces read-only fields when details-locked. Canvas enforces position when position-locked. Lock is changeable even on locked nodes via multi-select.

42. **Edge inspector** -- Select an edge to view/edit its line style (solid/dashed/dotted) and color in the inspector.

## Architecture Decisions

### Why @Observable instead of ObservableObject

The app uses Swift's `@Observable` macro (introduced in Swift 5.9) rather than `ObservableObject` with `@Published`. This gives finer-grained observation -- SwiftUI only re-renders views that read the specific properties that changed, rather than re-rendering everything when any `@Published` property changes. This matters for a canvas app where you do not want node dragging to re-render the entire inspector.

### Why NSViewRepresentable for Mouse Handling

SwiftUI's gesture system cannot handle the complexity needed for a graph editor:
- Distinguishing between clicking a node, clicking a port, clicking an edge, clicking empty space
- Drag behaviors that change mid-drag (start dragging a node vs. start creating an edge)
- Right-click panning
- Modifier key tracking (Shift for multi-select, Option for pan)
- Shape resize handles (8 handles per shape, drag from edges/corners)

The solution is `CanvasNSView: NSView` wrapped in `NSViewRepresentable`. The NSView gets `mouseDown`, `mouseDragged`, `mouseUp`, `rightMouseDown`, etc. and translates them into mutations on the `GraphDocument`. The SwiftUI layer observes those mutations and re-renders.

### Why SwiftUI Canvas for Edges (not regular Views)

Edges are rendered using SwiftUI's `Canvas` drawing primitive (not `Path` views) because:
- Edges need custom hit testing (clicking near a bezier curve)
- There can be many edges, and `Canvas` is more efficient than individual `Path` views
- Hop-over rendering requires analyzing all edges together to find intersections

### Why a Custom ZIP Writer

The app needs to create ZIP files for the `.ag` project format and Markdown export. Rather than pulling in a third-party dependency, it implements a minimal ZIP writer (~100 lines) using the store method (no compression) with `zlib.crc32()` for checksums. This keeps the project dependency-free.

### Port Position Tracking via PreferenceKey

Each `NodePortView` reports its screen position using a SwiftUI `PreferenceKey`. The canvas collects all port positions into a dictionary `[UUID: CGPoint]` and passes them to the edge layer for rendering. This is the cleanest way to connect SwiftUI layout (where ports end up on screen) with custom drawing (where to draw edge endpoints).

### Version Snapshots in ZIP

Versions are stored as JSON files inside the `.ag` ZIP under a `versions/` directory. Each snapshot is a full `ProjectManifest` (nodes, edges, metadata) with a name, timestamp, and optional note. This approach:
- Keeps versions self-contained within the project file — no external version control needed
- Is fully backward compatible — old app versions simply ignore the `versions/` directory
- Uses ISO 8601 dates in filenames for natural sorting: `versions/2026-03-12T10-30-00_Initial-Design.json`

### Infinite Canvas Grid

The dot grid background is drawn in screen space, not canvas space. `InfiniteGridView` calculates visible dot positions from the current offset and scale, always covering the entire viewport. The grid spacing scales with zoom, and when dots get too close together (below ~6px spacing), the grid doubles its spacing to stay readable. This avoids the old approach of a fixed-size `GridPatternView` that nodes could be dragged off of.

### Two-Phase File Opening (Blank Window Reuse)

When opening a file (double-click from Finder, File > Open, or Open Recent), the app uses a two-phase notification pattern to avoid creating unnecessary blank windows:

1. **Phase 1:** File data is stored in `PendingFileLoad.shared` and a `.loadPendingOrOpenNew` notification is posted. All existing windows receive this notification. Any **blank** window (`nodes.isEmpty && fileURL == nil && !isDirty`) consumes the pending data via `loadFromPending()` and loads the file directly.

2. **Phase 2 (fallback):** After a 0.15s delay, `NewWindowListener` checks `PendingFileLoad.shared.hasPending`. If no blank window consumed the data, it calls `openWindow(id: "main")` to create a new window, which picks up the data in `onAppear`.

This replaces the old approach of unconditionally posting `.requestNewWindow` (which always created a new window). The `.requestNewWindow` notification is still used when you explicitly want a new window (e.g., File > New Window, or File > Open from a window that already has content).

### watsonx Orchestrate Importer

The wxO importer (`WxOImporter.swift`) reads a folder of YAML files exported from IBM watsonx Orchestrate and converts them into a graph. It:

1. Recursively scans all subfolders for `.yaml`/`.yml` files
2. Classifies each file as agent, tool, knowledge base, or OpenAPI spec (by checking for key fields like `agents:`, `tools:`, `knowledge_bases:`, `openapi:` anywhere in the file content — no prefix limits)
3. Expands OpenAPI specs into individual Tool nodes (one per path/method)
4. Creates edges from agents to their referenced tools and knowledge bases
5. Auto-layouts the graph: agents top row, tools middle, knowledge bottom, centered around the canvas origin

The importer returns a `GraphDocument` with all nodes and edges pre-configured.

### Per-Window Dark/Light Mode

The canvas dark/light toggle is per-window, not global. This is implemented via `.preferredColorScheme(document.darkCanvas ? .dark : .light)` on `ContentView`'s body.

**Why not `NSApp.appearance`?** That sets the appearance globally for ALL windows — toggling one window changes every window.

**Why not `window.appearance`?** Setting `window.appearance` via `WindowAccessor` (NSView layer) happens after SwiftUI renders, so the SwiftUI `Canvas` drawing primitive does not redraw until something else triggers a layout pass (e.g., moving a node). `.preferredColorScheme()` participates in SwiftUI's render cycle and properly triggers redraws.

### Sidebar Visibility Toggles

Each palette item has an eye toggle that adds/removes its `NodeKind` from `document.hiddenNodeKinds: Set<NodeKind>` (runtime only, not persisted). When a kind is hidden:

- Canvas rendering skips those nodes (both shape and standard layers)
- `EdgeLayerView` skips edges where either endpoint's node kind is hidden
- Hit-testing (`hitTestNode`, `hitTestAllNodes`, `hitTestPort`) skips hidden kinds
- The `.draggable()` modifier is conditionally omitted (not just disabled at the drop destination)
- Inspector navigation buttons (pan-to-node from edge endpoints and connections) are disabled for hidden kinds

### No-Window File Open

When all windows are closed and the user triggers File > Open, Open Recent, or Import wxO, a `PendingLoadWatcher` (app-level `@Observable` object) observes the `.loadPendingOrOpenNew` notification. If no visible windows exist to consume the pending data, it calls `openWindow(id: "main")` to create one. The new window picks up the pending data in `onAppear`. `NSApp.activate()` is called in all `NSOpenPanel` completion handlers to ensure the app comes to the foreground.

### Multi-Select Inspector

The batch editor filters selected items by type (agents, tools, knowledge, edges) with toggle chips. Each field has an individual enable checkbox — only enabled fields are applied. This prevents accidentally overwriting fields you did not intend to change. Lock state changes are special-cased to bypass the "details locked" filter, otherwise you could never unlock a locked node via multi-select.

### Coordinate Spaces

The app uses two coordinate spaces:
- **Canvas coordinates** -- the "world" space where nodes have absolute positions
- **Screen coordinates** -- what you see on screen, affected by zoom and pan

Converting between them: `screenPos = (canvasPos * scale) + offset`

The canvas has a named coordinate space (`coordinateSpace(name: "canvas")`) so that preference keys report positions in a consistent frame.

## Gotchas and Pitfalls

### Xcode Project Format

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16.3+). This means new `.swift` files added to the `Agentic Graph/` folder are automatically discovered -- **you do not need to edit `project.pbxproj`** to add files. However, this also means you cannot manually control build phases per-file.

To exclude `Info.plist` from the "Copy Bundle Resources" phase (which causes a warning), you need a `PBXFileSystemSynchronizedBuildFileExceptionSet` in the pbxproj.

### Build Command

`xcode-select` may point to CommandLineTools rather than the full Xcode. Always use the full path:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project "Agentic Graph.xcodeproj" \
  -scheme "Agentic Graph" \
  -configuration Debug build
```

### SourceKit False Positives

SourceKit (the Swift language server) frequently reports false errors like "Cannot find type 'GraphDocument' in scope" or "Value of type 'GraphNode' has no member 'agentFramework'". These are SourceKit indexing failures, not real errors. **If `xcodebuild` reports BUILD SUCCEEDED, the code is correct.** Do not chase these phantom errors.

### Swift Concurrency and MainActor

The project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which means all types are implicitly `@MainActor` unless explicitly marked otherwise. This affects:

- `PreferenceKey` conformance: The `defaultValue` must be `static let`, not `static var`, because `nonisolated` on a `static var` in a `PreferenceKey` is not allowed under strict concurrency.
- `Transferable` conformance: The `transferRepresentation` property needs `nonisolated` since `Transferable` is a non-isolated protocol.

### SwiftUI Body Complexity / Type-Checker Limits

The Swift compiler can fail with "the compiler is unable to type-check this expression in reasonable time" when a SwiftUI `body` property has too many chained modifiers or inline views. This happened in `ContentView.swift` when version sheets, alerts, and focus values were all added to `body`. The fix is to extract sub-expressions into computed properties (e.g., `mainContent`) or helper methods (e.g., `handleOnAppear()`). If you see this error, split the body — do not try to simplify the logic.

### Dynamic Node Height for Hit Testing

Standard nodes (agent, tool, knowledge) grow taller as ports are added, but the stored `node.size.height` was initially fixed at 80pt. This caused the clickable area to not match the visual area. The fix is a `GeometryReader` background on `NodeView` that tracks the actual rendered height and updates `node.size.height` whenever it changes. Shape nodes are excluded — their height is user-controlled via resize handles.

### Data.withUnsafeBytes Ambiguity

In the ZIP writer, calling `Data.withUnsafeBytes(of:)` conflicts with the instance method on `Data`. You must prefix it with `Swift.withUnsafeBytes(of:)` to disambiguate.

### Import UniformTypeIdentifiers

Any file that references `.png`, `.zip`, or other system UTTypes needs `import UniformTypeIdentifiers`. This is easy to forget and the error message is not always clear.

### NSMenu Target in NSViewRepresentable

When creating an `NSMenu` for the right-click context menu inside `CanvasNSView`, each `NSMenuItem` must have `item.target = self` set explicitly. Without this, the `@objc` selector methods on the NSView will not be found and the menu items will appear disabled.

### Edge Creation Validation

Edge creation has multiple validation rules that must all be checked:
1. **No self-connections** -- source and target must be different nodes
2. **No duplicate edges** -- cannot connect the same pair of nodes twice
3. **No cycles** -- BFS from target back to source must not find a path
4. **Port kind mismatch** -- must connect input to output (or vice versa)
5. **Single output** -- an output port can only have one outgoing edge

If you skip any of these, the graph can enter invalid states that break export and rendering.

### Port Auto-Creation and Cleanup

When a user drags an edge to a node (not a specific port), the app auto-creates a matching port. These auto-created ports (`isAutoCreated = true`) are automatically removed when they lose their last connection, but only if the user has not manually renamed them. This cleanup logic runs in `removeEdge()` and is easy to get wrong.

### Shape Z-Ordering

Shapes render below edges, which render below standard nodes. Within the shapes layer, z-order is determined by array position in `document.nodes`. The `bringShapeForward` / `sendShapeBackward` operations only move nodes within the shape subset -- they skip over non-shape nodes in the array.

### Canvas Zoom Math

The zoom controls and zoom-to-fit calculations are the most error-prone math in the app. Key formulas:

```
// Canvas position to screen position
screenX = (canvasX * scale) + offset.width
screenY = (canvasY * scale) + offset.height

// Screen position to canvas position
canvasX = (screenX - offset.width) / scale
canvasY = (screenY - offset.height) / scale

// Zoom to fit
let bbox = bounding box of all nodes (including node sizes)
let scaleX = viewportWidth / bbox.width
let scaleY = viewportHeight / bbox.height
let fitScale = min(scaleX, scaleY) * 0.85  // 85% padding
let clampedScale = clamp(fitScale, 0.2, 3.0)
offset = center of viewport - (center of bbox * clampedScale)
```

### Marquee Selection

Marquee selection uses canvas coordinates (not screen coordinates). The rectangle is stored as `CGRect` and nodes are tested for intersection using their bounding box (`position +/- size/2`). Shift-marquee adds to the existing selection rather than replacing it.

### TextEditor in macOS SwiftUI

SwiftUI's `TextEditor` on macOS has quirks:
- `.scrollContentBackground(.hidden)` is needed to remove the default white background for custom styling, but `.visible` is better when you want the system look (as in the inspector Details field).
- There is no built-in placeholder text for `TextEditor`. If you need placeholder text, you must overlay it manually or use a different approach.
- Height is not auto-sized. You must set an explicit `.frame(height:)` or it will take all available space. The app uses `DragResizeHandle` (a custom `NSViewRepresentable`) for user-resizable text areas.

### DragResizeHandle

The resize handle for text editors is implemented as an `NSViewRepresentable` wrapping a custom `NSView`. A pure SwiftUI `DragGesture` was tried first but caused visual ghosting artifacts on macOS. The AppKit implementation with `mouseDown`/`mouseDragged` is smoother.

### PopoverColorPicker and NSColorPanel

The color picker uses `NSColorPanel.shared` for the system color picker. On macOS, `NSColorPanel` is a singleton that stays open across the app. The picker communicates via `NSColorPanel.shared.setTarget()` and `setAction()`. Be careful with the target lifecycle -- if the target is deallocated while the panel is open, the app will crash.

### Backward Compatibility for File Format

When adding new fields to `GraphNode` or `ProjectManifest`, always:
1. Make new fields optional with `nil` defaults
2. Use `decodeIfPresent` in any custom `init(from decoder:)`
3. Only encode non-default values to keep files clean

This ensures old `.ag` files continue to open correctly. The app also maintains legacy name mappings (e.g., `"drawBox"` decodes to `.shapeRectangle`) for very old files.

### Gatekeeper on Distributed Builds

When sharing the built app with others, macOS Gatekeeper will block it because it is not notarized. Recipients need to:
1. Go to System Settings > Privacy & Security
2. Scroll down to find "Agentic Graph was blocked"
3. Click "Open Anyway"

Or run: `xattr -cr "/path/to/Agentic Graph.app"`

### .buttonStyle(.plain) Hit Area on macOS

When using `.buttonStyle(.plain)` on macOS, the clickable area is limited to the visible pixels of the content — not the frame. For buttons with thin SF Symbols (like `minus`), the hit area is nearly impossible to click. Always add `.contentShape(Rectangle())` to the button's label to extend the hit area to the full frame:

```swift
Button { action() } label: {
    Image(systemName: "minus")
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
```

### .ag ZIP Compression Method

The custom `ZIPReader` only handles uncompressed (STORED, method 0) ZIP entries. When generating `.ag` files externally (e.g., Python scripts for example files), always use `zipfile.ZIP_STORED`, not `zipfile.ZIP_DEFLATED`. Files compressed with DEFLATE will fail to import silently.

### App Sandbox and File Access

The app is sandboxed (`ENABLE_APP_SANDBOX = YES`). File access outside the sandbox container requires security-scoped bookmarks. The recent files manager stores these bookmarks so files can be re-opened across app launches. Always call `url.startAccessingSecurityScopedResource()` before reading and `stopAccessingSecurityScopedResource()` when done.

### LSApplicationCategoryType

Xcode warns "No App Category is set" if you do not add `LSApplicationCategoryType` to Info.plist. Set it to `public.app-category.developer-tools` (or your preferred category).

### Info.plist in Copy Bundle Resources

With `PBXFileSystemSynchronizedRootGroup`, Xcode may auto-include `Info.plist` in the Copy Bundle Resources phase, causing a warning. Fix this by adding a `PBXFileSystemSynchronizedBuildFileExceptionSet` to `project.pbxproj` that excludes `Info.plist` from the resources phase.

## Testing Checklist

After building, verify these core workflows:

- [ ] Drag each node type from sidebar to canvas
- [ ] Connect two nodes by dragging between ports
- [ ] Verify self-connection is prevented
- [ ] Verify cycle detection (A->B->C, then try C->A)
- [ ] Select multiple nodes with Shift+Click and marquee
- [ ] Align and distribute multi-selected nodes
- [ ] Right-click context menu on nodes
- [ ] Copy/Paste nodes (Cmd+C/V) -- verify edges between copied nodes are preserved
- [ ] Save as .ag file, close, reopen -- verify all data restored
- [ ] Export PNG, HTML, and Markdown -- verify content
- [ ] Settings (Cmd+,) -- set Agent defaults, create new Agent, verify defaults applied
- [ ] Close app with unsaved changes -- verify session restore on relaunch
- [ ] Fill in project metadata, save, reopen -- verify metadata persisted
- [ ] Toggle dark/light canvas mode (per-window — other windows should not change)
- [ ] Zoom in/out, zoom to fit, 1:1 reset (all zoom bar buttons respond to clicks)
- [ ] Delete nodes and edges
- [ ] Undo/Redo after node operations
- [ ] Resize shapes via drag handles
- [ ] Edge styling: change line style (solid/dashed/dotted) and color via inspector
- [ ] Edge selection: click on an edge, verify inspector shows edge properties
- [ ] Port click: click a port dot with a connected edge, verify the edge is selected
- [ ] Inspector pan-to-node: click a node name in the edge inspector, verify canvas pans to that node
- [ ] Select connected nodes: select an edge, click "Select Connected Nodes", verify both nodes selected
- [ ] Sidebar visibility: toggle eye icon off for a kind, verify its nodes/edges hidden, drag disabled
- [ ] Sidebar visibility: toggle eye icon on, verify nodes/edges reappear
- [ ] Import wxO: File > Import watsonx Orchestrate Project, select a folder, verify graph created with correct node types and edges
- [ ] Multi-select inspector: select 2+ nodes, enable fields, apply changes
- [ ] Multi-select with edges: verify edge fields (style, color) are batch-editable
- [ ] Node locking: set each lock state, verify position/details restrictions
- [ ] Multi-select lock: lock nodes, then use multi-select to unlock them
- [ ] Create version: File > Create Version, fill name/note, verify appears in inspector
- [ ] Version history: open list, verify all versions shown with dates and counts
- [ ] Revert version: revert to earlier version, verify document restores, undo works
- [ ] Delete version: delete a version, verify undo restores it
- [ ] Versions persist in file: save with versions, reopen, verify versions still present
- [ ] Open old .ag file without versions: verify loads fine with empty version list
- [ ] HTML export: verify colored borders, risk/lock badges, edge styles, port labels
- [ ] Infinite canvas: drag nodes far from origin, verify grid dots always visible
- [ ] Port reordering: drag ports in inspector, verify order changes on canvas
- [ ] Open .ag file from Finder into blank window: verify file loads in existing window (no extra blank window)
- [ ] Open .ag file from Finder into window with content: verify new window opens for the file
- [ ] File > Open from blank window: verify file loads into that window
- [ ] File > Open from window with content: verify new window opens for the file
- [ ] Open example files from examples/ folder: verify they load correctly with all metadata
- [ ] Close all windows, File > Open: verify new window created and file loads
- [ ] Close all windows, File > Open Recent: verify new window created and file loads
- [ ] Close all windows, File > Import wxO: verify new window created and graph loads
