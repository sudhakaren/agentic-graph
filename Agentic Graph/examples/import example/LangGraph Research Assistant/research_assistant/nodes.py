"""Node functions for the research assistant graph.

Each function takes the shared ResearchState and returns a partial update.
The two `*_decision` / `needs_*` functions are routers used by the graph's
conditional edges rather than graph nodes.
"""
from research_assistant.state import ResearchState


def plan_research(state: ResearchState) -> dict:
    """Break the research question into a list of concrete sub-questions."""
    question = state["question"]
    sub_questions = [
        f"What is the current state of: {question}?",
        f"What are the main risks or open problems in: {question}?",
        f"Who are the key players relevant to: {question}?",
    ]
    return {"sub_questions": sub_questions}


def run_research(state: ResearchState) -> dict:
    """Investigate the next open sub-question, optionally calling a tool."""
    # A real implementation would call an LLM that may emit tool calls.
    return {"findings": ["(placeholder finding)"]}


def needs_tools(state: ResearchState) -> str:
    """Route to the tool node when the researcher requested a tool call."""
    if state.get("sub_questions"):
        return "call_tools"
    return "done"


def write_report(state: ResearchState) -> dict:
    """Draft the research report from the gathered findings."""
    findings = "\n".join(state.get("findings", []))
    return {"report": f"# Research Report\n\n{findings}"}


def review_report(state: ResearchState) -> dict:
    """Critique the drafted report for accuracy and completeness."""
    return {"review_notes": "Looks complete.", "revisions": state.get("revisions", 0) + 1}


def review_decision(state: ResearchState) -> str:
    """Decide whether the report needs another revision pass or is approved."""
    if state.get("revisions", 0) < 2 and "incomplete" in state.get("review_notes", ""):
        return "revise"
    return "approve"
