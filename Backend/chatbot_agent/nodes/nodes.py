import json
from typing import Any

from chatbot_agent.llm import get_llm

VALID_LEVELS = {
    "easy": "Easy",
    "medium": "Medium",
    "hard": "Hard",
}


def _clean_json_content(content: str) -> str:
    content = content.strip()
    if content.startswith("```json"):
        content = content[7:]
    elif content.startswith("```"):
        content = content[3:]
    if content.endswith("```"):
        content = content[:-3]
    return content.strip()


def normalize_subject_name(raw_input: str) -> str:
    llm = get_llm()
    prompt = f"""
You are normalizing a subject name entered by a student.

Task:
1. Fix spelling mistakes automatically.
2. Convert abbreviations or noisy phrasing into the most likely clean subject name.
3. Return ONLY the corrected subject name.
4. If the input is not a subject at all, return exactly INVALID.

Examples:
- "pythin" -> "Python"
- "dtaa strutures" -> "Data Structures"
- "machin lerning" -> "Machine Learning"
- "engg chem 1" -> "Engineering Chemistry 1"
- "hello how are you" -> "INVALID"

Input: "{raw_input}"
Output:
"""
    return llm.invoke(prompt).content.strip()


def generate_subject_prerequisites(subject: str) -> dict[str, Any]:
    llm = get_llm()
    prompt = f"""
Generate ONLY the subject-level prerequisites needed to learn "{subject}".

Return ONLY valid JSON in this exact format:
{{
  "subject": "{subject}",
  "prerequisites": [
    {{
      "order": 1,
      "subject": "Foundational Subject Name",
      "why": "Short reason why this subject is needed before the next one"
    }}
  ]
}}

Rules:
1. Include only subjects, never topics or subtopics.
2. Order must be sequential from the root foundation to the final prerequisite just before "{subject}".
3. Do not include "{subject}" inside the prerequisites array.
4. Keep the list concise and realistic.
5. Every item must have order, subject, and why.
6. Use ascending order starting from 1.
7. Return JSON only.
"""

    content = _clean_json_content(llm.invoke(prompt).content)
    raw_data = json.loads(content)
    prerequisites = raw_data.get("prerequisites", [])

    normalized = []
    seen = set()

    for index, item in enumerate(prerequisites, start=1):
        if not isinstance(item, dict):
            continue

        prerequisite_subject = str(item.get("subject", "")).strip()
        if not prerequisite_subject:
            continue

        key = prerequisite_subject.lower()
        if key in seen:
            continue
        seen.add(key)

        normalized.append(
            {
                "order": index,
                "subject": prerequisite_subject,
                "why": str(item.get("why", "")).strip(),
            }
        )

    return {
        "subject": subject,
        "prerequisites": normalized,
    }


def generate_quiz(subject: str, level: str, prerequisite_data: dict[str, Any] | None) -> dict[str, Any]:
    llm = get_llm()
    normalized_level = VALID_LEVELS.get(level, "Easy")
    prerequisite_list = prerequisite_data.get("prerequisites", []) if prerequisite_data else []

    prompt = f"""
Generate a quiz JSON for the subject "{subject}".

Difficulty level: {normalized_level}
Prerequisite context:
{json.dumps(prerequisite_list, ensure_ascii=False)}

Return ONLY valid JSON in this exact schema:
{{
  "subject": "{subject}",
  "level": "{normalized_level}",
  "prerequisites": [],
  "questions": [
    {{
      "id": "SUBJ_001",
      "topic": "Topic Name",
      "concept": "Concept Name",
      "difficulty": "{level}",
      "type": "theory",
      "question": "Question text",
      "options": {{
        "A": "Option A",
        "B": "Option B",
        "C": "Option C",
        "D": "Option D"
      }},
      "correct_answer": "A"
    }}
  ]
}}

Rules:
1. Generate exactly 10 questions.
2. Every question must be multiple choice with exactly 4 options: A, B, C, D.
3. Include keys exactly as shown: id, topic, concept, difficulty, type, question, options, correct_answer.
4. Use only these values for difficulty: easy, medium, hard.
5. Match the requested difficulty level overall, but small variation is allowed if helpful.
6. Use subject-appropriate types such as theory, conceptual, numerical, coding, or application.
7. If the subject naturally allows coding/programming questions, include 1 to 4 coding questions.
8. If the subject does not support coding naturally, do not force coding questions.
9. correct_answer must be exactly one of: A, B, C, D.
10. Questions must be clear, non-duplicate, and aligned to the subject.
11. Return JSON only.
"""

    content = _clean_json_content(llm.invoke(prompt).content)
    raw_data = json.loads(content)
    raw_questions = raw_data.get("questions", [])

    normalized_questions = []

    for index, item in enumerate(raw_questions[:10], start=1):
        if not isinstance(item, dict):
            continue

        options = item.get("options", {})
        if isinstance(options, list) and len(options) >= 4:
            options = {
                "A": str(options[0]),
                "B": str(options[1]),
                "C": str(options[2]),
                "D": str(options[3]),
            }
        elif isinstance(options, dict):
            options = {
                "A": str(options.get("A", "")),
                "B": str(options.get("B", "")),
                "C": str(options.get("C", "")),
                "D": str(options.get("D", "")),
            }
        else:
            options = {"A": "", "B": "", "C": "", "D": ""}

        answer = str(item.get("correct_answer", "A")).strip().upper()
        if answer not in {"A", "B", "C", "D"}:
            answer = "A"

        normalized_questions.append(
            {
                "id": str(item.get("id", f"QUIZ_{index:03d}")).strip() or f"QUIZ_{index:03d}",
                "topic": str(item.get("topic", subject)).strip(),
                "concept": str(item.get("concept", f"Concept {index}")).strip(),
                "difficulty": str(item.get("difficulty", level)).strip().lower() or level,
                "type": str(item.get("type", "theory")).strip().lower() or "theory",
                "question": str(item.get("question", "")).strip(),
                "options": options,
                "correct_answer": answer,
            }
        )

    if len(normalized_questions) != 10:
        raise ValueError(f"Expected 10 questions but received {len(normalized_questions)}")

    return {
        "subject": subject,
        "level": normalized_level,
        "prerequisites": prerequisite_list,
        "questions": normalized_questions,
    }


def detect_user_intent_choice(message: str) -> str | None:
    text = message.lower().strip()

    test_keywords = [
        "test",
        "quiz",
        "mcq",
        "assessment",
    ]
    prerequisite_keywords = [
        "graph",
        "flowchart",
        "roadmap",
        "prerequisite",
        "prerequisites",
        "prereq",
        "pre req",
        "pre-req",
        "pre requisite",
        "pre requisites",
        "pre requiste",
        "pre requeste",
        "pre request",
    ]

    if any(keyword in text for keyword in test_keywords):
        return "test"

    if any(keyword in text for keyword in prerequisite_keywords):
        return "flowchart"

    return None


def router_node(state):
    print("\n[ROUTER NODE CALLED]")
    print(f"STATE -> {state}")

    subject = state.get("subject")
    target_subject = state.get("target_subject")
    message = (state.get("message") or "").strip()
    message_lower = message.lower()
    intent = state.get("intent")
    prerequisite_data = state.get("prerequisite_data")
    failed_questions = state.get("failed_questions")
    current_prereq_index = state.get("current_prereq_index")
    remediation_mode = state.get("remediation_mode")

    if state.get("step") == "choose_level":
        level = message_lower

        if level not in VALID_LEVELS:
            return {
                "response": "Please choose a valid difficulty level: Easy, Medium, or Hard.",
                "step": "choose_level",
                "subject": subject,
                "intent": "test",
                "level": None,
                "prerequisite_data": prerequisite_data,
                "failed_questions": failed_questions,
                "target_subject": target_subject,
                "current_prereq_index": current_prereq_index,
                "remediation_mode": remediation_mode,
            }

        return {
            "subject": subject,
            "target_subject": target_subject,
            "intent": "test",
            "level": level,
            "step": "level_selected",
            "prerequisite_data": prerequisite_data,
            "failed_questions": failed_questions,
            "current_prereq_index": current_prereq_index,
            "remediation_mode": remediation_mode,
        }

    if not subject:
        if message:
            extracted_subject = normalize_subject_name(message)

            if extracted_subject == "INVALID" or not extracted_subject:
                return {
                    "response": "Please enter a valid subject name.",
                    "step": "get_subject",
                    "subject": None,
                    "intent": None,
                    "level": None,
                    "prerequisite_data": None,
                    "quiz_data": None,
                    "failed_questions": [],
                    "target_subject": None,
                    "current_prereq_index": None,
                    "remediation_mode": False,
                }

            generated_prerequisites = generate_subject_prerequisites(extracted_subject)
            print(f"SUBJECT -> {extracted_subject}")
            print("PREREQUISITES ->")
            print(json.dumps(generated_prerequisites, indent=2, ensure_ascii=False))

            return {
                "response": f"You selected {extracted_subject}. Do you want prerequisites or a test?",
                "step": "awaiting_intent",
                "subject": extracted_subject,
                "target_subject": extracted_subject,
                "intent": None,
                "level": None,
                "prerequisite_data": generated_prerequisites,
                "quiz_data": None,
                "failed_questions": [],
                "current_prereq_index": len(generated_prerequisites.get("prerequisites", [])),
                "remediation_mode": False,
            }

        return {
            "response": "What subject would you like to learn?",
            "step": "get_subject",
            "subject": None,
            "target_subject": None,
            "intent": None,
            "level": None,
            "prerequisite_data": None,
            "quiz_data": None,
            "failed_questions": [],
            "current_prereq_index": None,
            "remediation_mode": False,
        }

    if subject and not prerequisite_data:
        prerequisite_data = generate_subject_prerequisites(subject)
    if current_prereq_index is None and prerequisite_data:
        current_prereq_index = len(prerequisite_data.get("prerequisites", []))
    if not target_subject:
        target_subject = subject

    if subject and not intent:
        intent_choice = detect_user_intent_choice(message_lower)

        if intent_choice == "test":
            return {
                "subject": subject,
                "target_subject": target_subject,
                "intent": "test",
                "step": "choose_level",
                "response": "Please choose a difficulty level: Easy, Medium, or Hard.",
                "level": None,
                "prerequisite_data": prerequisite_data,
                "quiz_data": None,
                "failed_questions": failed_questions,
                "current_prereq_index": current_prereq_index,
                "remediation_mode": remediation_mode,
            }

        if intent_choice == "flowchart":
            return {
                "subject": subject,
                "target_subject": target_subject,
                "intent": "flowchart",
                "step": "intent_classified",
                "message": message,
                "level": None,
                "prerequisite_data": prerequisite_data,
                "quiz_data": None,
                "failed_questions": failed_questions,
                "current_prereq_index": current_prereq_index,
                "remediation_mode": remediation_mode,
            }

        return {
            "response": "Please choose: graph or test.",
            "step": "awaiting_intent",
            "subject": subject,
            "target_subject": target_subject,
            "intent": None,
            "level": None,
            "prerequisite_data": prerequisite_data,
            "quiz_data": None,
            "failed_questions": failed_questions,
            "current_prereq_index": current_prereq_index,
            "remediation_mode": remediation_mode,
        }

    return state


def generate_flowchart(state):
    print("\n[GRAPH NODE - SUBJECT PREREQUISITES]")
    print(f"SUBJECT -> {state.get('subject')}")

    main_subject = state.get("subject")
    target_subject = state.get("target_subject") or main_subject
    prerequisite_data = state.get("prerequisite_data")

    if not main_subject:
        error_graph = {
            "subject": None,
            "prerequisites": [],
            "error": "No subject provided",
        }
        return {
            "response": json.dumps(error_graph, indent=2, ensure_ascii=False),
            "prerequisite_data": error_graph,
            "step": "end",
            "error": "No subject provided",
            "quiz_data": None,
            "failed_questions": state.get("failed_questions"),
        }

    if not prerequisite_data:
        prerequisite_data = generate_subject_prerequisites(target_subject)

    print("PREREQUISITES JSON ->")
    print(json.dumps(prerequisite_data, indent=2, ensure_ascii=False))

    return {
        "response": "Prerequisites generated. Check the terminal log for the JSON output.",
        "prerequisite_data": prerequisite_data,
        "step": "end",
        "intent": "flowchart",
        "quiz_data": None,
        "failed_questions": state.get("failed_questions"),
        "target_subject": target_subject,
        "current_prereq_index": state.get("current_prereq_index"),
        "remediation_mode": state.get("remediation_mode"),
    }


def generate_test(state):
    print("\n[TEST NODE - GENERATING QUIZ]")

    subject = state.get("subject")
    target_subject = state.get("target_subject") or subject
    level = (state.get("level") or "easy").lower()
    prerequisite_data = state.get("prerequisite_data")

    if not subject:
        error_response = {
            "subject": None,
            "difficulty": VALID_LEVELS.get(level, "Easy"),
            "prerequisites": [],
            "questions": [],
            "error": "No subject provided",
        }
        return {
            "response": "No subject provided.",
            "prerequisite_data": error_response,
            "quiz_data": None,
            "step": "end",
            "error": "No subject provided",
            "failed_questions": state.get("failed_questions"),
            "target_subject": target_subject,
            "current_prereq_index": state.get("current_prereq_index"),
            "remediation_mode": state.get("remediation_mode"),
        }

    if not prerequisite_data:
        prerequisite_data = generate_subject_prerequisites(subject)

    quiz_data = generate_quiz(subject, level, prerequisite_data)

    print(f"SUBJECT -> {subject}")
    print(f"LEVEL -> {VALID_LEVELS.get(level, 'Easy')}")
    print("PREREQUISITES ->")
    print(json.dumps(prerequisite_data, indent=2, ensure_ascii=False))
    print("QUIZ JSON ->")
    print(json.dumps(quiz_data, indent=2, ensure_ascii=False))

    return {
        "response": f"Generated a 10-question {VALID_LEVELS.get(level, 'Easy')} quiz for {subject}. Answer it below.",
        "prerequisite_data": prerequisite_data,
        "quiz_data": quiz_data,
        "step": "end",
        "level": level,
        "failed_questions": state.get("failed_questions"),
        "target_subject": target_subject,
        "current_prereq_index": state.get("current_prereq_index"),
        "remediation_mode": state.get("remediation_mode"),
    }
