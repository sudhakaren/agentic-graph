"""Function tools for the customer support agents."""
from agents import function_tool


@function_tool
def lookup_invoice(invoice_id: str) -> str:
    """Look up the status and amount of a customer invoice by its ID."""
    return f"Invoice {invoice_id}: paid, $42.00."


@function_tool
def search_knowledge_base(query: str) -> str:
    """Search the product knowledge base for troubleshooting articles."""
    return f"(placeholder knowledge base results for: {query})"


@function_tool
def process_refund(invoice_id: str, reason: str) -> str:
    """Issue a refund for an invoice, recording the stated reason."""
    return f"Refund issued for {invoice_id} ({reason})."
