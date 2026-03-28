from typing import TypedDict, Optional, Dict, Any

class GraphState(TypedDict):
    subject: Optional[str]
    message: Optional[str]
    intent: Optional[str]
    response: Optional[str]
    step: str
    prerequisite_data: Optional[Dict[str, Any]]  # JSON data from LLM
    error: Optional[str]