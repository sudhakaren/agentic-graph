"""Shared state for the research assistant graph."""
from operator import add
from typing import Annotated, TypedDict


class ResearchState(TypedDict):
    """State threaded through every node of the research assistant graph."""
    question: str
    sub_questions: list[str]
    findings: Annotated[list[str], add]
    report: str
    review_notes: str
    revisions: int
