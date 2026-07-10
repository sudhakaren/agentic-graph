"""Graph definition for the research assistant.

Wires the node functions into a LangGraph StateGraph with a tool-calling loop
and a writer/reviewer revision loop.
"""
from langgraph.graph import StateGraph, START, END
from langgraph.prebuilt import ToolNode

from research_assistant.state import ResearchState
from research_assistant.nodes import (
    plan_research,
    run_research,
    needs_tools,
    write_report,
    review_report,
    review_decision,
)
from research_assistant.tools import research_tools


def build_graph():
    """Construct and compile the research assistant graph."""
    builder = StateGraph(ResearchState)

    builder.add_node("planner", plan_research)
    builder.add_node("researcher", run_research)
    builder.add_node("tools", ToolNode(research_tools))
    builder.add_node("writer", write_report)
    builder.add_node("reviewer", review_report)

    builder.add_edge(START, "planner")
    builder.add_edge("planner", "researcher")
    builder.add_conditional_edges(
        "researcher",
        needs_tools,
        {"call_tools": "tools", "done": "writer"},
    )
    builder.add_edge("tools", "researcher")
    builder.add_edge("writer", "reviewer")
    builder.add_conditional_edges(
        "reviewer",
        review_decision,
        {"revise": "writer", "approve": END},
    )

    return builder.compile()


graph = build_graph()
