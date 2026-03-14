"""
Content moderation service.
Fast in-process filter for English and Hindi profanity/harmful content.
Returns (flagged: bool, reason: str).
"""

import re

# ── English bad words (core list — extend as needed) ────────────────────────
_EN_WORDS = {
    # Sexual
    "fuck", "fucker", "fucking", "fucked", "fucks",
    "shit", "shitting", "bullshit",
    "asshole", "arsehole",
    "bitch", "bitches",
    "cunt", "dick", "cock", "pussy", "whore", "slut",
    "motherfucker", "bastard",
    "porn", "rape", "rapist",
    # Hate / slurs
    "nigger", "nigga", "faggot", "fag", "retard", "kike", "chink",
    "spic", "wetback",
    # Self-harm triggers (flag for context, not block)
    "kill yourself", "kys", "go die",
    # Harassment
    "i will kill", "i'll kill", "going to kill you", "gonna kill you",
}

# ── Hindi bad words (Devanagari + romanised transliterations) ────────────────
_HI_WORDS = {
    # Romanised
    "madarchod", "madarjaat", "bhenchod", "behen ke lode", "bsdk",
    "randi", "chutiya", "chut", "lund", "lauda", "gaand", "gaandu",
    "harami", "kamina", "saala", "saali", "chakka", "hijra",
    "kutte", "kamine", "mc", "bc",
    # Common leetspeak / abbreviations
    "mchd", "bnchd",
}

# ── Devanagari Unicode ──────────────────────────────────────────────────────
_DEVANAGARI_WORDS = {
    "मादरचोद", "भेनचोद", "रंडी", "चुतिया", "लंड", "गांड",
    "हरामी", "कमीना", "साला", "चक्का",
}

_ALL_WORDS = _EN_WORDS | _HI_WORDS | _DEVANAGARI_WORDS

# Pre-compile: match whole words and common leet substitutions
def _build_pattern(word: str) -> re.Pattern:
    escaped = re.escape(word)
    return re.compile(r'\b' + escaped + r'\b', re.IGNORECASE)

_PATTERNS = {word: _build_pattern(word) for word in _ALL_WORDS if ' ' not in word}
# Phrase patterns (no word boundary for multi-word phrases)
_PHRASE_PATTERNS = {
    phrase: re.compile(re.escape(phrase), re.IGNORECASE)
    for phrase in _ALL_WORDS if ' ' in phrase
}


def _normalise(text: str) -> str:
    """Normalise common obfuscation tricks."""
    text = text.lower()
    # Remove zero-width characters used to bypass filters
    text = re.sub(r'[\u200b-\u200f\u2060\ufeff]', '', text)
    # Common leet substitutions
    text = text.replace('@', 'a').replace('3', 'e').replace('1', 'i')
    text = text.replace('0', 'o').replace('$', 's').replace('5', 's')
    text = text.replace('!', 'i').replace('4', 'a')
    # Remove repeated characters beyond 3 (fuuuck → fuuck)
    text = re.sub(r'(.)\1{2,}', r'\1\1', text)
    # Remove dots/underscores/hyphens used to split words (f.u.c.k → fuck)
    text = re.sub(r'(?<=[a-z])[._\-*](?=[a-z])', '', text)
    return text


async def check_content(text: str) -> tuple[bool, str]:
    """
    Check text for inappropriate content.
    Returns (flagged, reason). reason is empty string if not flagged.
    """
    if not text or not text.strip():
        return False, ""

    normalised = _normalise(text)
    original_lower = text.lower()

    # Check single-word patterns against normalised text
    for word, pattern in _PATTERNS.items():
        if pattern.search(normalised):
            return True, f"contains '{word}'"

    # Check phrase patterns against original (phrases are harder to obfuscate)
    for phrase, pattern in _PHRASE_PATTERNS.items():
        if pattern.search(original_lower):
            return True, f"contains phrase '{phrase}'"

    return False, ""
