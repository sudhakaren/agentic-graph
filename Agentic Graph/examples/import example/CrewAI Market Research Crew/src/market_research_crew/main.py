#!/usr/bin/env python
import sys

from market_research_crew.crew import MarketResearchCrew


def run():
    """Run the Market Research crew."""
    inputs = {
        'sector': 'AI developer tools',
        'region': 'North America',
    }
    MarketResearchCrew().crew().kickoff(inputs=inputs)


if __name__ == '__main__':
    run()
