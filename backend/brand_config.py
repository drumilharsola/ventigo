"""
Brand configuration loader.

Reads ``brand.config.json`` from the project root and exposes it as a
simple module-level singleton.  Every string that once lived as a
hard-coded "UNBurDEN" now comes from ``brand.*`` instead.

Environment-variable overrides (optional):
  BRAND_APP_NAME, BRAND_SENDER_NAME, BRAND_SENDER_EMAIL, BRAND_SUPPORT_EMAIL
"""

import json
import os
from pathlib import Path
from types import SimpleNamespace

_CONFIG_PATH = Path(__file__).resolve().parent.parent / "brand.config.json"

def _load() -> SimpleNamespace:
    with open(_CONFIG_PATH, encoding="utf-8") as fh:
        raw = json.load(fh)

    # allow env overrides for the most commonly changed fields
    raw["appName"]      = os.getenv("BRAND_APP_NAME",      raw["appName"])
    raw["senderName"]   = os.getenv("BRAND_SENDER_NAME",   raw["senderName"])
    raw["senderEmail"]  = os.getenv("BRAND_SENDER_EMAIL",  raw["senderEmail"])
    raw["supportEmail"] = os.getenv("BRAND_SUPPORT_EMAIL", raw["supportEmail"])

    logo = SimpleNamespace(**raw["logo"])
    theme = SimpleNamespace(**raw["theme"])
    return SimpleNamespace(
        app_name       = raw["appName"],
        app_name_plain = raw["appNamePlain"],
        tagline        = raw["tagline"],
        description    = raw["description"],
        support_email  = raw["supportEmail"],
        sender_name    = raw["senderName"],
        sender_email   = raw["senderEmail"],
        logo           = logo,
        theme          = theme,
    )

brand = _load()
