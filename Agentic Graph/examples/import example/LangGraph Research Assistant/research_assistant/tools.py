"""Tools available to the research assistant.

These are bound into a single LangGraph ToolNode in graph.py, so the importer
represents them as one "tools" node in the graph.
"""
from langchain_core.tools import tool


@tool
def web_search(query: str) -> str:
    """Search the web for up-to-date information on a query."""
    return f"(placeholder web results for: {query})"


@tool
def fetch_url(url: str) -> str:
    """Fetch and extract the readable text content of a web page."""
    return f"(placeholder page text for: {url})"


research_tools = [web_search, fetch_url]
