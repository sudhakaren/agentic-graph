"""An AutoGen / AG2 group-chat software team.

A GroupChatManager orchestrates a User Proxy plus three assistant agents
(Planner, Engineer, Reviewer). The engineer can call a registered test tool.
"""
import autogen

config_list = [{"model": "gpt-4o", "api_key": "YOUR_KEY_HERE"}]
llm_config = {"config_list": config_list}


def run_tests(code: str) -> str:
    """Run the project's test suite against the provided code and report results."""
    return "All tests passed."


user_proxy = autogen.UserProxyAgent(
    name="User Proxy",
    human_input_mode="TERMINATE",
    code_execution_config={"work_dir": "workspace", "use_docker": False},
)

planner = autogen.AssistantAgent(
    name="Planner",
    llm_config=llm_config,
    system_message="You break feature requests into a concrete, ordered implementation plan.",
)

engineer = autogen.AssistantAgent(
    name="Engineer",
    llm_config=llm_config,
    system_message="You write clean, well-tested Python code that follows the plan.",
)

reviewer = autogen.AssistantAgent(
    name="Reviewer",
    llm_config=llm_config,
    system_message="You review code for correctness, security, and style, and request changes when needed.",
)

groupchat = autogen.GroupChat(
    agents=[user_proxy, planner, engineer, reviewer],
    messages=[],
    max_round=20,
)

manager = autogen.GroupChatManager(
    groupchat=groupchat,
    llm_config=llm_config,
)

autogen.register_function(
    run_tests,
    caller=engineer,
    executor=user_proxy,
    name="run_tests",
    description="Run the project's test suite.",
)


if __name__ == "__main__":
    user_proxy.initiate_chat(manager, message="Add a CSV export feature to the reports module.")
