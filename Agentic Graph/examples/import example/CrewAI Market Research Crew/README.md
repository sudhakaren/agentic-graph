# Market Research Crew

A sample [CrewAI](https://crewai.com) project for testing the Agentic Graph
**Import CrewAI Project** feature.

It defines a four-agent **sequential** crew that sizes a market and produces a
board-ready go-to-market recommendation:

- **Research Analyst** — gathers market size and demand data
  (tools: Serper web search, custom Market Data Lookup)
- **Competitor Analyst** — maps the competitive landscape
  (tools: Serper web search, website scraper)
- **Market Strategist** — synthesises a go-to-market strategy (can delegate)
- **Report Writer** — produces the final executive report

## Task flow

```
market_research_task ──┐
                       ├──► strategy_task ──► report_task
competitor_analysis ───┘
```

`strategy_task` lists `market_research_task` and `competitor_analysis_task` as
its `context`, and `report_task` lists `strategy_task` — so the importer draws
edges Research Analyst → Market Strategist, Competitor Analyst → Market
Strategist, and Market Strategist → Report Writer.

## Importing into Agentic Graph

**File → Import CrewAI Project…**, then choose this folder. The importer reads:

- `src/market_research_crew/config/agents.yaml` — agent roles, goals, backstories, models
- `src/market_research_crew/config/tasks.yaml` — task assignments and `context` dependencies
- `src/market_research_crew/crew.py` — the process type and per-agent tool wiring
- `src/market_research_crew/tools/market_data_tool.py` — the custom `MarketDataTool`

## Running the crew

This is a sample for import testing; to actually run it you would need a
CrewAI environment:

```bash
pip install 'crewai[tools]'
crewai run
```
