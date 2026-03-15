"""Tests for services/moderation.py - pure functions, no mocking needed."""

import pytest
from services.moderation import check_content, _normalise


# -- _normalise ----------------------------------------------------------------

def test_normalise_lowercases():
    assert _normalise("HELLO") == "hello"


def test_normalise_leet_speak():
    assert _normalise("h3ll0") == "hello"
    assert _normalise("$h!t") == "shit"
    assert _normalise("4$$") == "ass"


def test_normalise_zero_width_chars():
    text = "fu\u200bck"
    assert "\u200b" not in _normalise(text)


def test_normalise_repeated_chars():
    assert _normalise("fuuuuuck") == "fuuck"


def test_normalise_dot_separated():
    assert _normalise("f.u.c.k") == "fuck"
    assert _normalise("s_h_i_t") == "shit"
    assert _normalise("b-i-t-c-h") == "bitch"


# -- check_content -------------------------------------------------------------

@pytest.mark.asyncio
async def test_clean_text_passes():
    flagged, reason = await check_content("Hello, how are you today?")
    assert flagged is False
    assert reason == ""


@pytest.mark.asyncio
async def test_empty_text_passes():
    flagged, reason = await check_content("")
    assert flagged is False
    assert reason == ""


@pytest.mark.asyncio
async def test_whitespace_only_passes():
    flagged, reason = await check_content("   ")
    assert flagged is False
    assert reason == ""


@pytest.mark.asyncio
async def test_none_text_passes():
    flagged, reason = await check_content(None)
    assert flagged is False


@pytest.mark.asyncio
async def test_english_profanity_flagged():
    flagged, _ = await check_content("what the fuck")
    assert flagged is True


@pytest.mark.asyncio
async def test_english_slur_flagged():
    flagged, _ = await check_content("you are a bitch")
    assert flagged is True


@pytest.mark.asyncio
async def test_english_profanity_case_insensitive():
    flagged, _ = await check_content("FUCK this")
    assert flagged is True


@pytest.mark.asyncio
async def test_hindi_profanity_romanised():
    flagged, _ = await check_content("tu madarchod hai")
    assert flagged is True


@pytest.mark.asyncio
async def test_hindi_profanity_romanised_2():
    flagged, _ = await check_content("saala chutiya")
    assert flagged is True


@pytest.mark.asyncio
async def test_devanagari_profanity():
    flagged, _ = await check_content("तू मादरचोद है")
    assert flagged is True


@pytest.mark.asyncio
async def test_leet_speak_evasion():
    flagged, _ = await check_content("f.u.c.k you")
    assert flagged is True


@pytest.mark.asyncio
async def test_leet_speak_dollar():
    flagged, _ = await check_content("$hit happens")
    assert flagged is True


@pytest.mark.asyncio
async def test_zero_width_bypass():
    flagged, _ = await check_content("fu\u200bck")
    assert flagged is True


@pytest.mark.asyncio
async def test_repeated_chars_normalisation():
    from services.moderation import _normalise
    assert _normalise("fuuuuuck") == "fuuck"
    assert _normalise("shhhhit") == "shhit"


@pytest.mark.asyncio
async def test_phrase_kill_yourself():
    flagged, _ = await check_content("just kill yourself")
    assert flagged is True


@pytest.mark.asyncio
async def test_phrase_kys():
    flagged, _ = await check_content("kys bro")
    assert flagged is True


@pytest.mark.asyncio
async def test_harassment_phrase():
    flagged, _ = await check_content("i will kill you")
    assert flagged is True


@pytest.mark.asyncio
async def test_normal_sentences_pass():
    sentences = [
        "I'm feeling really down today",
        "Can we talk about something?",
        "The weather is nice outside",
        "I love listening to music",
        "Thank you for being here",
    ]
    for s in sentences:
        flagged, _ = await check_content(s)
        assert flagged is False, f"False positive on: {s}"


@pytest.mark.asyncio
async def test_mixed_profanity_and_normal():
    flagged, _ = await check_content("hello asshole goodbye")
    assert flagged is True
