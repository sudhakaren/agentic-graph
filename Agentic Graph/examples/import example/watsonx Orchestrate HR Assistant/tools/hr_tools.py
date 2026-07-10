"""Custom Python tools for the watsonx Orchestrate HR Assistant.

Each function is decorated with @tool so the watsonx Orchestrate ADK can
import it and make it callable by an agent.
"""
from ibm_watsonx_orchestrate.agent_builder.tools import tool


@tool
def lookup_benefits(employee_id: str) -> dict:
    """Return an employee's current benefit elections and coverage levels."""
    return {
        "employee_id": employee_id,
        "health": "PPO Family",
        "dental": "Standard",
        "vision": "Standard",
        "retirement": "6% employee contribution",
    }


@tool
def enroll_in_plan(employee_id: str, plan_name: str, effective_date: str) -> str:
    """Enrol an employee in a benefit plan with the given effective date."""
    return f"{employee_id} enrolled in {plan_name}, effective {effective_date}."


@tool
def check_leave_balance(employee_id: str) -> dict:
    """Report the remaining vacation, sick, and personal days for an employee."""
    return {"employee_id": employee_id, "vacation": 12, "sick": 5, "personal": 2}


@tool
def request_leave(employee_id: str, leave_type: str, start_date: str, end_date: str) -> str:
    """Submit a leave request for the employee's manager to approve."""
    return (
        f"{leave_type} leave requested for {employee_id} "
        f"from {start_date} to {end_date}."
    )


@tool
def get_payslip(employee_id: str, pay_period: str) -> dict:
    """Retrieve the payslip for an employee for a given pay period."""
    return {
        "employee_id": employee_id,
        "pay_period": pay_period,
        "gross_pay": 4200.00,
        "net_pay": 3120.55,
    }
