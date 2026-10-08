"""Bounded web and journal metadata retrieval; source text is untrusted."""
import httpx
from app.config import get_settings
from app.brain.tools.base import BaseTool

class ResearchSearch(BaseTool):
    name = ""
    description = "Search climate evidence"
    parameters = {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}
    def __init__(self, settings=None, transport=None):
        self.settings = settings or get_settings()
        self.transport = transport
    async def execute(self, query, **kwargs):
        if not query.strip() or len(query) > 1000:
            raise ValueError("Query must contain 1–1000 characters")
        if self.name == "tavily_search" and not self.settings.tavily_api_key:
            raise RuntimeError("Tavily is not configured")
        async with httpx.AsyncClient(timeout=15, transport=self.transport) as client:
            if self.name == "tavily_search":
                if not self.settings.tavily_api_key:
                    raise RuntimeError("Tavily is not configured")
                r = await client.post("https://api.tavily.com/search", headers={"Authorization": f"Bearer {self.settings.tavily_api_key}"}, json={"query": query, "max_results": 5, "include_answer": False})
                r.raise_for_status()
                return {"sources": [{"title": w.get("title"), "url": w.get("url"), "excerpt": w.get("content", "")[:1500]} for w in r.json().get("results", [])]}
            headers = {"Authorization": f"Bearer {self.settings.openalex_api_key}"} if self.settings.openalex_api_key else {}
            r = await client.get("https://api.openalex.org/works", headers=headers, params={"search": query, "filter": "type:article,primary_location.source.type:journal", "per-page": 5})
            r.raise_for_status()
            return {"papers": [{"title": w.get("display_name"), "url": w.get("doi") or w.get("id"), "year": w.get("publication_year"), "journal": ((w.get("primary_location") or {}).get("source") or {}).get("display_name"), "peer_review_status": "not independently verified"} for w in r.json().get("results", [])]}
