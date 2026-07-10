<p align="center">
  <img src="AgenticGraphIcon.png" width="128" height="128" alt="Agentic Graph icon">
</p>

<h1 align="center">Agentic Graph</h1>

<p align="center">
  A macOS application for designing agentic AI network graphs.<br>
  Build visual architectures for multi-agent systems with drag-and-drop,<br>
  edge creation, and rich documentation export.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/UI-SwiftUI-purple" alt="SwiftUI">
  <img src="https://img.shields.io/badge/dependencies-none-green" alt="No Dependencies">
</p>

<p align="center">
  <img src="sample UI.png" width="800" alt="Agentic Graph screenshot showing a shopping agent architecture">
</p>

## What is it for?

Agentic Graph helps you plan, document and test agentic AI architectures before you build them. It is framework-agnostic and supports common agent orchestration platforms including watsonx Orchestrate, LangChain, CrewAI, AutoGen, Semantic Kernel, and OpenAI Agents.

## Features

- **Visual graph editor** — drag agents, tools, knowledge sources, humans, and shapes onto an infinite, zoomable canvas.
- **Port-to-port connections** — wire components together with curved edges to model information flow and delegation.
- **Rich node metadata** — capture framework, model, complexity, memory, delegation, latency and cost budgets, and dozens of other fields.
- **AI-assisted analysis** — review the architecture against a library of 37 patterns and anti-patterns, with findings graded by severity.
- **Prompt Analysis** — get an AI review of an agent's instructions for clarity, scope, and routing problems.
- **Infrastructure sizing** — instant estimates of compute tier, workload profile, and scaling recommendations from the graph.
- **Load Simulation (beta)** — heuristic per-agent latency prediction with typical and p95 response-time figures.
- **Framework importers** — turn an existing watsonx Orchestrate, CrewAI, LangGraph, OpenAI Agents SDK, or AutoGen / AG2 project into a graph.
- **Documentation export** — PNG images, HTML and Markdown reports, and a complete Markdown documentation package.
- **Version snapshots** — capture and restore named project milestones, stored inside the `.ag` file.
- **Multi-window editing** — work on several projects at once, each with its own light or dark canvas.
- **Localised into 14 languages** — including English, Japanese, Korean, Arabic, and ten more.

For more details see the [manual](manual).

## Quick Start

1. Open the project in Xcode and run it, or use the build script to export a distributable app:
   ```bash
   ./build-export.sh
   ```
   This creates `AgenticGraph.zip` in `./built`.

2. Launch the app. The sidebar on the left shows all available node types. Drag any node onto the canvas to get started.

3. Connect nodes by dragging from one port dot to another. Ports are the small circles on each node.

4. Click any empty area on the canvas to see and edit the project-level details in the inspector on the right.

## Building from Source

Requirements:
- macOS with Xcode installed
- No third-party dependencies

```bash
# Build via command line
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project "Agentic Graph.xcodeproj" \
  -scheme "Agentic Graph" \
  -configuration Debug build

# Or create a distributable ZIP
./build-export.sh
```

The project uses `PBXFileSystemSynchronizedRootGroup`, so new `.swift` files added to the `Agentic Graph/` folder are automatically discovered by Xcode without editing `project.pbxproj`.

## Sharing the App

Since this is not distributed via the App Store, recipients may see a Gatekeeper warning. They can open the app via:

**System Settings > Privacy & Security > scroll down to "Agentic Graph was blocked" > Open Anyway**

Or from Terminal:
```bash
xattr -cr "/path/to/Agentic Graph.app"
```
# agentic-graph
