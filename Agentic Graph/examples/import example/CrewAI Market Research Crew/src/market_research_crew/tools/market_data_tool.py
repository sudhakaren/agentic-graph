from crewai.tools import BaseTool
from pydantic import BaseModel, Field


class MarketDataInput(BaseModel):
    """Input schema for MarketDataTool."""
    sector: str = Field(..., description="The market sector to look up.")
    region: str = Field(..., description="The geographic region of interest.")


class MarketDataTool(BaseTool):
    name: str = "Market Data Lookup"
    description: str = "Looks up structured market sizing data (market value, CAGR, segment breakdown) for a given sector and region."
    args_schema: type[BaseModel] = MarketDataInput

    def _run(self, sector: str, region: str) -> str:
        # Placeholder — a real implementation would call a market-data API.
        return f"Market data for {sector} in {region}: market value, CAGR, and segment breakdown."
