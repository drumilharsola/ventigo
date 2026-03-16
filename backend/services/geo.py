"""
Geo-IP service - detect country from IP using ipapi.co (free HTTPS, no key required).
Falls back to "global" if detection fails.
"""

import httpx
from config import get_settings


async def detect_country(ip: str) -> str:
    """
    Returns ISO 3166-1 alpha-2 country code (e.g. 'IN', 'US')
    or 'global' if detection fails.
    """
    # Skip private / loopback addresses
    if ip in ("127.0.0.1", "::1", "localhost") or ip.startswith("192.168.") or ip.startswith("10."):
        return "global"

    try:
        settings = get_settings()
        url = f"{settings.GEO_API_URL}{ip}/country_code/"
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(url)
            if resp.status_code == 200:
                code = resp.text.strip()
                if len(code) == 2 and code.isalpha():
                    return code
    except Exception:
        pass

    return "global"
