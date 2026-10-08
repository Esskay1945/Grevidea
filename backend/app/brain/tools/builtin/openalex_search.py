from app.brain.tools.builtin.research import ResearchSearch
class OpenAlexSearch(ResearchSearch):
    name = "openalex_search"
    description = "Retrieve journal articles and DOI metadata; peer review is not independently verified."
