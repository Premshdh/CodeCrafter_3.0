from typing import TypedDict, Optional, Dict, Any

class GraphState(TypedDict):
    subject: Optional[str]
    target_subject: Optional[str]
    message: Optional[str]
    intent: Optional[str]
    level: Optional[str]
    response: Optional[str]
    step: str
    prerequisite_data: Optional[Dict[str, Any]]
    quiz_data: Optional[Dict[str, Any]]
    failed_questions: Optional[list[Dict[str, Any]]]
    current_prereq_index: Optional[int]
    remediation_mode: Optional[bool]
    error: Optional[str]
