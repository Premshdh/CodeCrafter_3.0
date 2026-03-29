from typing import Any
import json

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from chatbot_agent import run_agent
from chatbot_agent.nodes.nodes import generate_subject_prerequisites
from chatbot_agent.llm.llm import get_feedback_llm

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str | None = None
    subject: str | None = None
    target_subject: str | None = None
    intent: str | None = None
    level: str | None = None
    step: str | None = "start"
    prerequisite_data: dict[str, Any] | None = None
    quiz_data: dict[str, Any] | None = None
    failed_questions: list[dict[str, Any]] | None = None
    current_prereq_index: int | None = None
    remediation_mode: bool | None = False


class JsonRequest(BaseModel):
    subject: str


class QuizEvaluationRequest(BaseModel):
    quiz_data: dict[str, Any]
    answers: dict[str, str | None]
    failed_questions: list[dict[str, Any]] | None = None
    prerequisite_data: dict[str, Any] | None = None
    target_subject: str | None = None
    current_prereq_index: int | None = None
    remediation_mode: bool | None = False


LEVEL_ORDER = ["easy", "medium", "hard"]
PASS_THRESHOLD = 0.6


def get_next_level(current_level: str, passed: bool) -> str:
    current = (current_level or "easy").lower()
    if current not in LEVEL_ORDER:
        current = "easy"

    index = LEVEL_ORDER.index(current)

    if passed:
        return LEVEL_ORDER[min(index + 1, len(LEVEL_ORDER) - 1)]

    return LEVEL_ORDER[max(index - 1, 0)]


def generate_weakness_feedback(subject: str, failed_questions: list[dict[str, Any]]) -> str:
    llm = get_feedback_llm()
    prompt = f"""
You are analyzing a student's quiz mistakes.

Subject: {subject}
Failed question history:
{json.dumps(failed_questions, indent=2, ensure_ascii=False)}

Write a concise feedback summary that explains:
1. Which portions or concepts seem weak
2. Any recurring pattern in mistakes
3. What the student should revise first

Keep it short, practical, and student-friendly.
Return plain text only.
"""
    return llm.invoke(prompt).content.strip()


def get_prerequisite_sequence(target_subject: str, prerequisite_data: dict[str, Any] | None) -> list[str]:
    sequence = []
    if prerequisite_data:
        for item in prerequisite_data.get("prerequisites", []):
            name = str(item.get("subject", "")).strip()
            if name:
                sequence.append(name)
    if target_subject:
        sequence.append(target_subject)
    return sequence


@app.post("/chat")
def chat(req: ChatRequest):
    state = {
        "subject": req.subject if req.subject else None,
        "target_subject": req.target_subject if req.target_subject else req.subject,
        "message": req.message,
        "intent": req.intent,
        "level": req.level,
        "step": req.step or "start",
        "prerequisite_data": req.prerequisite_data,
        "quiz_data": req.quiz_data,
        "failed_questions": req.failed_questions or [],
        "current_prereq_index": req.current_prereq_index,
        "remediation_mode": req.remediation_mode,
    }

    result = run_agent(state)

    return {
        "response": result.get("response"),
        "step": result.get("step"),
        "intent": result.get("intent"),
        "subject": result.get("subject"),
        "target_subject": result.get("target_subject"),
        "level": result.get("level"),
        "prerequisite_data": result.get("prerequisite_data"),
        "quiz_data": result.get("quiz_data"),
        "failed_questions": result.get("failed_questions"),
        "current_prereq_index": result.get("current_prereq_index"),
        "remediation_mode": result.get("remediation_mode"),
    }


@app.post("/json")
def generate_prerequisites(req: JsonRequest):
    print(f"\n[/json ENDPOINT CALLED] Subject: {req.subject}")

    try:
        prerequisite_data = generate_subject_prerequisites(req.subject)
        pretty_json = json.dumps(prerequisite_data, indent=2, ensure_ascii=False)

        return {
            "prerequisite_data": prerequisite_data,
            "response": pretty_json,
            "success": True
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")


@app.post("/evaluate-quiz")
def evaluate_quiz(req: QuizEvaluationRequest):
    quiz_data = req.quiz_data or {}
    questions = quiz_data.get("questions", [])
    accumulated_failed_questions = list(req.failed_questions or [])
    prerequisite_data = req.prerequisite_data or {}
    target_subject = req.target_subject or quiz_data.get("subject")
    remediation_mode = bool(req.remediation_mode)
    sequence = get_prerequisite_sequence(str(target_subject or ""), prerequisite_data)
    current_level = str(quiz_data.get("level", "Easy")).lower()
    current_subject = str(quiz_data.get("subject", target_subject or ""))

    if req.current_prereq_index is not None:
        current_prereq_index = req.current_prereq_index
    elif current_subject in sequence:
        current_prereq_index = sequence.index(current_subject)
    else:
        current_prereq_index = max(len(sequence) - 1, 0)

    results = []
    score = 0

    for question in questions:
        question_id = question.get("id")
        user_answer = req.answers.get(question_id)
        correct_answer = question.get("correct_answer")
        is_correct = user_answer == correct_answer

        if is_correct:
            score += 1

        results.append(
            {
                "id": question_id,
                "topic": question.get("topic"),
                "concept": question.get("concept"),
                "type": question.get("type"),
                "difficulty": question.get("difficulty"),
                "question": question.get("question"),
                "user_answer": user_answer,
                "correct_answer": correct_answer,
                "is_correct": is_correct,
            }
        )

        if not is_correct:
            accumulated_failed_questions.append(
                {
                    "id": question_id,
                    "topic": question.get("topic"),
                    "concept": question.get("concept"),
                    "type": question.get("type"),
                    "difficulty": question.get("difficulty"),
                    "question": question.get("question"),
                    "user_answer": user_answer,
                    "correct_answer": correct_answer,
                    "level": quiz_data.get("level"),
                }
            )

    evaluation = {
        "subject": quiz_data.get("subject"),
        "target_subject": target_subject,
        "level": quiz_data.get("level"),
        "score": score,
        "total": len(questions),
        "results": results,
    }

    total_questions = len(questions)
    passed = total_questions > 0 and (score / total_questions) >= PASS_THRESHOLD
    next_level = None
    next_subject = current_subject
    next_prereq_index = current_prereq_index
    next_remediation_mode = remediation_mode
    quiz_ended = False

    if remediation_mode:
        if current_level == "medium":
            if passed:
                next_level = "hard"
                transition_message = f"Passed Medium on {current_subject}. Moving to Hard on {current_subject}."
            else:
                next_level = "easy"
                transition_message = f"Failed Medium on {current_subject}. Moving to Easy on {current_subject}."
        elif current_level == "easy":
            if passed:
                quiz_ended = True
                next_level = None
                transition_message = f"Passed Easy on prerequisite subject {current_subject}. Generating feedback."
            else:
                previous_index = current_prereq_index - 1
                if previous_index >= 0 and previous_index < len(sequence):
                    next_subject = sequence[previous_index]
                    next_prereq_index = previous_index
                    next_level = "medium"
                    next_remediation_mode = True
                    transition_message = (
                        f"Failed Easy on prerequisite subject {current_subject}. Moving back to "
                        f"{next_subject} and starting at Medium."
                    )
                else:
                    quiz_ended = True
                    next_level = None
                    transition_message = (
                        f"Failed Easy on prerequisite subject {current_subject}. No earlier prerequisite available. "
                        f"Generating feedback."
                    )
        else:
            quiz_ended = True
            next_level = None
            if passed:
                transition_message = (
                    f"Passed Hard on prerequisite subject {current_subject}. "
                    f"Generating feedback from full incorrect-question history."
                )
            else:
                transition_message = (
                    f"Failed Hard on prerequisite subject {current_subject}. "
                    f"Generating feedback from full incorrect-question history."
                )
    else:
        if current_level == "easy" and not passed:
            previous_index = current_prereq_index - 1
            if previous_index >= 0 and previous_index < len(sequence):
                next_subject = sequence[previous_index]
                next_prereq_index = previous_index
                next_level = "medium"
                next_remediation_mode = True
                transition_message = (
                    f"Failed Easy on {current_subject}. Moving back to prerequisite subject "
                    f"{next_subject} and starting at Medium."
                )
            else:
                quiz_ended = True
                next_level = None
                transition_message = f"Failed Easy on {current_subject}. No earlier prerequisite available. Generating feedback."
        elif current_level == "easy" and passed:
            next_level = "medium"
            transition_message = f"Passed Easy on {current_subject}. Next level: Medium."
        elif current_level == "medium" and passed:
            next_level = "hard"
            transition_message = f"Passed Medium on {current_subject}. Next level: Hard."
        elif current_level == "medium" and not passed:
            quiz_ended = True
            next_level = None
            transition_message = (
                f"Failed Medium on {current_subject} after reaching the intermediate stage. "
                f"Generating feedback."
            )
        elif current_level == "hard" and passed:
            quiz_ended = True
            next_level = None
            transition_message = f"Passed Hard on {current_subject}. Generating feedback."
        else:
            quiz_ended = True
            next_level = None
            transition_message = (
                f"Failed Hard on {current_subject} after reaching the advanced stage. "
                f"Generating feedback."
            )

    evaluation["passed"] = passed
    evaluation["next_level"] = next_level
    evaluation["next_subject"] = next_subject
    evaluation["next_prereq_index"] = next_prereq_index
    evaluation["next_remediation_mode"] = next_remediation_mode
    evaluation["transition_message"] = transition_message
    evaluation["failed_questions"] = accumulated_failed_questions
    evaluation["quiz_ended"] = quiz_ended

    if quiz_ended:
        if accumulated_failed_questions:
            feedback = generate_weakness_feedback(
                str(target_subject or quiz_data.get("subject", "Unknown Subject")),
                accumulated_failed_questions
            )
        else:
            feedback = "No major weak areas were detected from this quiz path. The student appears comfortable with the tested portions."
        evaluation["feedback"] = feedback
    else:
        evaluation["feedback"] = None

    print("QUIZ SUBMISSION RESULT ->")
    print(json.dumps(evaluation, indent=2, ensure_ascii=False))

    if evaluation["feedback"]:
        print("GEMINI FEEDBACK ->")
        print(evaluation["feedback"])

    return evaluation


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
