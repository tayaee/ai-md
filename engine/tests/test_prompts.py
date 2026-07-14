from aimd.prompts import (
    CLASSIFY_SYSTEM,
    SPA_SYSTEM,
    API_SYSTEM,
    FIX_TEMPLATE,
)


def test_constants_are_nonempty_strings():
    for value in (CLASSIFY_SYSTEM, SPA_SYSTEM, API_SYSTEM, FIX_TEMPLATE):
        assert isinstance(value, str)
        assert value.strip() != ""


def test_fix_template_formats_with_error():
    result = FIX_TEMPLATE.format(error="x")
    assert "x" in result


def test_spa_system_mentions_html():
    assert "HTML" in SPA_SYSTEM


def test_api_system_mentions_fastapi():
    assert "FastAPI" in API_SYSTEM
