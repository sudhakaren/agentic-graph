from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task
from crewai_tools import SerperDevTool, ScrapeWebsiteTool

from market_research_crew.tools.market_data_tool import MarketDataTool


@CrewBase
class MarketResearchCrew():
    """Market Research crew — sizes a market and recommends a go-to-market strategy."""

    agents_config = 'config/agents.yaml'
    tasks_config = 'config/tasks.yaml'

    @agent
    def research_analyst(self) -> Agent:
        return Agent(
            config=self.agents_config['research_analyst'],
            tools=[SerperDevTool(), MarketDataTool()],
            verbose=True,
        )

    @agent
    def competitor_analyst(self) -> Agent:
        return Agent(
            config=self.agents_config['competitor_analyst'],
            tools=[SerperDevTool(), ScrapeWebsiteTool()],
            verbose=True,
        )

    @agent
    def market_strategist(self) -> Agent:
        return Agent(
            config=self.agents_config['market_strategist'],
            verbose=True,
        )

    @agent
    def report_writer(self) -> Agent:
        return Agent(
            config=self.agents_config['report_writer'],
            verbose=True,
        )

    @task
    def market_research_task(self) -> Task:
        return Task(config=self.tasks_config['market_research_task'])

    @task
    def competitor_analysis_task(self) -> Task:
        return Task(config=self.tasks_config['competitor_analysis_task'])

    @task
    def strategy_task(self) -> Task:
        return Task(config=self.tasks_config['strategy_task'])

    @task
    def report_task(self) -> Task:
        return Task(
            config=self.tasks_config['report_task'],
            output_file='market_report.md',
        )

    @crew
    def crew(self) -> Crew:
        """Creates the Market Research crew."""
        return Crew(
            agents=self.agents,
            tasks=self.tasks,
            process=Process.sequential,
            verbose=True,
        )
