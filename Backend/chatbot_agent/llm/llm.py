import os
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_groq import ChatGroq

load_dotenv()


def get_llm():
    groq_api_key = os.getenv("GROQ_API_KEY")

    if groq_api_key:
        return ChatGroq(
            model=os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile"),
            temperature=0.3,
            groq_api_key=groq_api_key
        )

    return ChatGoogleGenerativeAI(
        model="gemini-2.5-flash",
        temperature=0.3,
        google_api_key=os.getenv("GOOGLE_API_KEY")
    )


def get_feedback_llm():
    google_api_key = os.getenv("GOOGLE_API_KEY")

    if google_api_key:
        return ChatGoogleGenerativeAI(
            model="gemini-2.5-flash",
            temperature=0.2,
            google_api_key=google_api_key
        )

    return get_llm()
