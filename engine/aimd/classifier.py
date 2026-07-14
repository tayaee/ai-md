import logging
from typing import Literal

from . import llm
from .config import Settings
from .prompts import CLASSIFY_SYSTEM

log = logging.getLogger("aimd.classifier")

Target = Literal["spa", "api"]

_API_KEYWORDS = ["POST", "GET", "PUT", "DELETE", "JSON", "API", "endpoint", "endpoint"]
_SPA_KEYWORDS = ["HTML", "UI", "screen", "page", "rendering", "design", "button", "game"]


def _count_occurrences(text: str, keywords: list[str]) -> int:
    return sum(text.count(k) for k in keywords)


def classify_by_keywords(spec_text: str) -> Target:
    """Case-sensitive keyword count. Returns "api" if the api score exceeds the
    spa score, otherwise "spa".
    (On a tie, "spa" — the landing-page side is the safer default)"""
    api_score = _count_occurrences(spec_text, _API_KEYWORDS)
    spa_score = _count_occurrences(spec_text, _SPA_KEYWORDS)
    return "api" if api_score > spa_score else "spa"


def classify(spec_text: str, settings: Settings) -> Target:
    """Calls llm.chat(CLASSIFY_SYSTEM, spec_text, settings).
    - strip().upper() the response: "SPA" -> "spa", "API" -> "api"
    - For any other answer, or if an Exception is raised:
      log.warning("LLM classification failed, falling back to keywords: %s", ...)
      then return the classify_by_keywords result
    """
    try:
        response = llm.chat(CLASSIFY_SYSTEM, spec_text, settings)
        answer = response.strip().upper()
        if answer == "SPA":
            return "spa"
        if answer == "API":
            return "api"
        log.warning(
            "LLM classification failed, falling back to keywords: %s", response
        )
    except Exception as e:
        log.warning(
            "LLM classification failed, falling back to keywords: %s", e
        )
    return classify_by_keywords(spec_text)