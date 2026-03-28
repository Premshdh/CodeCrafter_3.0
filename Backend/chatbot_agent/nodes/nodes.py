import json
from typing import List, Literal
from pydantic import BaseModel, Field, field_validator
from chatbot_agent.llm import get_llm

# ================= STRICT PYDANTIC SCHEMA ================= #
class Subject(BaseModel):
    """Subject node in the graph"""
    id: str = Field(..., description="Unique identifier (e.g., CS101, MA101)")
    name: str = Field(..., description="Full subject name (e.g., Intro to Programming)")
    type: Literal["core", "elective", "prerequisite"] = Field(..., description="Type of subject")
    desc: str = Field(..., description="Brief description of the subject")

class Dependency(BaseModel):
    """Edge connecting subjects: from -> to (prerequisite relationship)"""
    from_: str = Field(..., alias="from", description="ID of prerequisite subject")
    to: str = Field(..., description="ID of subject that requires the prerequisite")
    
    @field_validator('from_', 'to')
    @classmethod
    def ids_must_be_uppercase_alphanumeric(cls, v):
        if not v or len(v) < 2:
            raise ValueError('ID must be at least 2 characters')
        return v

class PrerequisiteGraph(BaseModel):
    """Root schema - strict format for directed graph"""
    subjects: List[Subject] = Field(..., description="List of all subjects/nodes")
    dependencies: List[Dependency] = Field(..., description="List of prerequisite relationships/edges")
    
    class Config:
        populate_by_name = True  # Allow 'from' as field name


def router_node(state):
    print("\n🔁 [ROUTER NODE CALLED]")
    print(f"STATE → {state}")

    llm = get_llm()
    subject = state.get("subject")
    message = state.get("message")
    intent = state.get("intent")

    if not subject:
        return {
            "response": "📘 What subject would you like to learn?",
            "step": "get_subject"
        }

    if subject and not intent and message == subject:
        return {
            "response": f"""
Great! You chose **{subject}**.

Do you want:
📊 View prerequisite graph (JSON with subjects & dependencies)
📝 Take a practice test  

Just tell me naturally 🙂
(e.g., "show prerequisites", "graph", "dependencies", "quiz me")
""",
            "step": "awaiting_intent"
        }

    if subject and not intent:
        prompt = f"""
You are an intent classifier.

User message:
"{message}"

Classify into:
- flowchart (if user wants prerequisites, graph, dependencies, roadmap)
- test (if user wants quiz, test, questions)

Return ONLY one word.
"""
        result = llm.invoke(prompt).content.strip().lower()
        print("🧠 LLM Intent:", result)

        return {
            "subject": subject,
            "intent": result,
            "step": "intent_classified"
        }

    return state


# ---------------- GRAPH NODE (STRICT PYDANTIC SCHEMA) ---------------- #

def generate_flowchart(state):
    print("\n📊 [GRAPH NODE - PYDANTIC VALIDATED]")
    print(f"SUBJECT → {state.get('subject')}")
    
    main_subject = state.get("subject")
    llm = get_llm()
    
    # Strict prompt for graph format with IDs
    prompt = f"""
Create a prerequisite graph for "{main_subject}".

Return ONLY valid JSON matching this EXACT structure (no extra fields):

{{
  "subjects": [
    {{
      "id": "CS101",
      "name": "Intro to Programming",
      "type": "core",
      "desc": "Learn Python basics and logic."
    }},
    {{
      "id": "MA101",
      "name": "Mathematics I",
      "type": "core",
      "desc": "Basic algebra and calculus."
    }},
    {{
      "id": "TARGET",
      "name": "{main_subject}",
      "type": "elective",
      "desc": "Main subject description."
    }}
  ],
  "dependencies": [
    {{"from": "CS101", "to": "TARGET"}},
    {{"from": "MA101", "to": "TARGET"}}
  ]
}}

RULES:
1. "subjects" array must contain 3-8 subjects with unique IDs (format: XX101, e.g., CS101, MA101, PY201, AI301)
2. Each subject MUST have exactly these 4 fields: id, name, type, desc
3. "type" must be exactly one of: "core", "elective", or "prerequisite"
4. "dependencies" array shows prerequisite relationships (from = prerequisite, to = dependent)
5. The main subject "{main_subject}" must have id "TARGET" or appropriate ID like "AI401"
6. IDs in dependencies must match subject IDs exactly
7. Create a DAG (Directed Acyclic Graph) - no circular dependencies
8. Valid JSON only - no trailing commas, no markdown, no comments
9. Use double quotes for all strings and keys

Example IDs: CS101, CS201, MA101, MA201, PY101, AI401, DS301, ALGO201
"""

    try:
        result = llm.invoke(prompt)
        content = result.content.strip()
        
        # Clean markdown
        if content.startswith("```json"):
            content = content[7:]
        elif content.startswith("```"):
            content = content[3:]
        if content.endswith("```"):
            content = content[:-3]
        content = content.strip()
        
        # Parse raw JSON
        raw_data = json.loads(content)
        
        # Validate with Pydantic - enforces strict schema
        try:
            graph = PrerequisiteGraph.model_validate(raw_data)
            validated_dict = graph.model_dump(by_alias=True)  # Use 'from' not 'from_'
        except Exception as validation_error:
            print(f"⚠️ Validation error: {validation_error}")
            # Attempt to fix common issues and re-validate
            fixed_data = fix_graph_data(raw_data, main_subject)
            graph = PrerequisiteGraph.model_validate(fixed_data)
            validated_dict = graph.model_dump(by_alias=True)
        
        # Pretty print for response
        pretty_json = json.dumps(validated_dict, indent=2, ensure_ascii=False)
        
        return {
            "response": pretty_json,
            "prerequisite_data": validated_dict,
            "step": "end"
        }
        
    except Exception as e:
        print(f"❌ Error: {e}")
        # Return error in same schema format
        error_graph = {
            "subjects": [
                {
                    "id": "ERROR",
                    "name": main_subject,
                    "type": "core",
                    "desc": f"Error generating graph: {str(e)}"
                }
            ],
            "dependencies": []
        }
        return {
            "response": json.dumps(error_graph, indent=2),
            "prerequisite_data": error_graph,
            "step": "end",
            "error": str(e)
        }


def fix_graph_data(raw_data: dict, main_subject: str) -> dict:
    """
    Fix common LLM errors before Pydantic validation.
    """
    subjects = raw_data.get("subjects", [])
    dependencies = raw_data.get("dependencies", [])
    
    # Ensure subjects is list
    if not isinstance(subjects, list):
        subjects = []
    
    # Ensure dependencies is list
    if not isinstance(dependencies, list):
        dependencies = []
    
    # Fix missing fields in subjects
    fixed_subjects = []
    for i, subj in enumerate(subjects):
        if not isinstance(subj, dict):
            continue
            
        fixed_subj = {
            "id": str(subj.get("id", f"SUBJ{i}")),
            "name": str(subj.get("name", f"Subject {i}")),
            "type": subj.get("type") if subj.get("type") in ["core", "elective", "prerequisite"] else "core",
            "desc": str(subj.get("desc", subj.get("description", "")))
        }
        fixed_subjects.append(fixed_subj)
    
    # Ensure main subject is included
    main_ids = [s["id"] for s in fixed_subjects]
    if "TARGET" not in main_ids and not any(main_subject in s["name"] for s in fixed_subjects):
        fixed_subjects.append({
            "id": "TARGET",
            "name": main_subject,
            "type": "elective",
            "desc": f"Main subject: {main_subject}"
        })
    
    # Fix dependencies (ensure 'from' and 'to' exist)
    fixed_deps = []
    for dep in dependencies:
        if isinstance(dep, dict) and "from" in dep and "to" in dep:
            fixed_deps.append({
                "from": str(dep["from"]),
                "to": str(dep["to"])
            })
    
    return {
        "subjects": fixed_subjects,
        "dependencies": fixed_deps
    }


# ---------------- TEST NODE ---------------- #

def generate_test(state):
    print("\n📝 [TEST NODE TRIGGERED]")
    print(f"SUBJECT → {state.get('subject')}")

    llm = get_llm()
    subject = state.get("subject")

    prompt = f"""
Create a 5-question multiple-choice test for {subject}.

Format each question as:
Q1. [Question text]
A) [Option]
B) [Option]
C) [Option]
D) [Option]

Correct Answer: [Letter]

Answer Key: Q1-[Letter], Q2-[Letter], Q3-[Letter], Q4-[Letter], Q5-[Letter]
"""

    result = llm.invoke(prompt)

    return {
        "response": result.content,
        "step": "end"
    }