"""
Push notification service via OneSignal REST API.
https://documentation.onesignal.com/reference/create-notification

Uses httpx (already a project dependency) - no extra packages needed.
"""

import logging
import httpx
from config import get_settings

logger = logging.getLogger(__name__)

ONESIGNAL_API_URL = "https://onesignal.com/api/v1/notifications"


async def send_push(
    *,
    player_ids: list[str] | None = None,
    external_ids: list[str] | None = None,
    heading: str,
    content: str,
    data: dict | None = None,
) -> bool:
    """
    Send a push notification via OneSignal.

    Use `player_ids` for OneSignal subscription IDs, or `external_ids`
    for your own user/session identifiers (set via OneSignal SDK).

    Returns True on success, False on failure (never raises).
    """
    settings = get_settings()

    if not settings.ONESIGNAL_APP_ID or not settings.ONESIGNAL_API_KEY:
        logger.debug("[DEV] OneSignal not configured - skipping push notification")
        return False

    payload: dict = {
        "app_id": settings.ONESIGNAL_APP_ID,
        "headings": {"en": heading},
        "contents": {"en": content},
    }

    if player_ids:
        payload["include_subscription_ids"] = player_ids
    elif external_ids:
        payload["include_aliases"] = {"external_id": external_ids}
        payload["target_channel"] = "push"
    else:
        logger.warning("send_push called with no target IDs")
        return False

    if data:
        payload["data"] = data

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                ONESIGNAL_API_URL,
                headers={
                    "Authorization": f"Key {settings.ONESIGNAL_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            resp.raise_for_status()
            logger.info(f"Push sent: {heading}")
            return True
    except Exception as exc:
        logger.error(f"OneSignal push failed: {exc}")
        return False


async def send_match_notification(session_id: str, room_id: str) -> bool:
    """Notify a user that they've been matched."""
    return await send_push(
        external_ids=[session_id],
        heading="You've been matched! 🎉",
        content="Someone is ready to listen. Tap to start your session.",
        data={"type": "match", "room_id": room_id},
    )
