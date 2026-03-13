"""
Email service - sends transactional emails via the Brevo API (https://brevo.com).
Uses httpx (already a project dependency) - no extra packages needed.

Dev mode: if BREVO_API_KEY is not set, the verification link is printed to the
console so you can click it directly during local development.
"""

import re
import logging
import httpx
from config import get_settings

logger = logging.getLogger(__name__)


def _parse_sender(smtp_from: str) -> dict:
    """Parse 'Name <email>' or plain 'email' into Brevo sender dict."""
    match = re.match(r'^(.+?)\s*<(.+?)>$', smtp_from.strip())
    if match:
        return {"name": match.group(1).strip(), "email": match.group(2).strip()}
    return {"name": "Unburden", "email": smtp_from.strip()}


async def send_verification_email(to_email: str, verify_url: str) -> None:
    settings = get_settings()

    # ── Dev fallback - no key configured ─────────────────────────────────────
    if not settings.RESEND_API_KEY:
        logger.warning(
            f"[DEV] BREVO_API_KEY not set. "
            f"Verification link for {to_email}: {verify_url}"
        )
        return

    html = f"""
    <html>
    <body style="font-family:'Comfortaa',sans-serif;background:#FFF8F0;color:#3B3335;padding:40px;">
      <div style="max-width:480px;margin:auto;background:#FFFFFF;border-radius:16px;padding:40px;border:1px solid #F0E8EA;">
        <h2 style="color:#3B3335;margin-top:0;font-size:22px;letter-spacing:-0.02em;">Unburden</h2>
        <p style="font-size:15px;color:#4D4448;margin:0 0 24px;">One click to verify your email address:</p>
        <a href="{verify_url}"
           style="display:inline-block;padding:14px 28px;background:#F4A68C;color:#3B3335;
                  border-radius:12px;text-decoration:none;font-weight:700;font-size:15px;">
          Verify my email &rarr;
        </a>
        <p style="font-size:13px;color:#8A7F85;margin:28px 0 0;">
          This link expires in <strong style="color:#4D4448;">24 hours</strong>.
        </p>
        <hr style="border:none;border-top:1px solid #F0E8EA;margin:24px 0;"/>
        <p style="font-size:11px;color:#8A7F85;">If you didn&rsquo;t create an Unburden account, ignore this email.</p>
      </div>
    </body>
    </html>
    """

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            "https://api.brevo.com/v3/smtp/email",
            headers={
                "api-key": settings.RESEND_API_KEY,
                "Content-Type": "application/json",
            },
            json={
                "sender": _parse_sender(settings.SMTP_FROM),
                "to": [{"email": to_email}],
                "subject": "Verify your Unburden email",
                "htmlContent": html,
                "textContent": (
                    f"Verify your Unburden account:\n{verify_url}\n\n"
                    "This link expires in 24 hours."
                ),
            },
        )
        resp.raise_for_status()


async def send_password_reset_email(to_email: str, reset_url: str) -> None:
    settings = get_settings()

    if not settings.RESEND_API_KEY:
        logger.warning(
            f"[DEV] BREVO_API_KEY not set. "
            f"Password reset link for {to_email}: {reset_url}"
        )
        return

    html = f"""
    <html>
    <body style="font-family:'Comfortaa',sans-serif;background:#FFF8F0;color:#3B3335;padding:40px;">
      <div style="max-width:480px;margin:auto;background:#FFFFFF;border-radius:16px;padding:40px;border:1px solid #F0E8EA;">
        <h2 style="color:#3B3335;margin-top:0;font-size:22px;letter-spacing:-0.02em;">Unburden</h2>
        <p style="font-size:15px;color:#4D4448;margin:0 0 24px;">Click the button below to reset your password:</p>
        <a href="{reset_url}"
           style="display:inline-block;padding:14px 28px;background:#F4A68C;color:#3B3335;
                  border-radius:12px;text-decoration:none;font-weight:700;font-size:15px;">
          Reset my password &rarr;
        </a>
        <p style="font-size:13px;color:#8A7F85;margin:28px 0 0;">
          This link expires in <strong style="color:#4D4448;">1 hour</strong>.
        </p>
        <hr style="border:none;border-top:1px solid #F0E8EA;margin:24px 0;"/>
        <p style="font-size:11px;color:#8A7F85;">If you didn&rsquo;t request a password reset, ignore this email.</p>
      </div>
    </body>
    </html>
    """

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            "https://api.brevo.com/v3/smtp/email",
            headers={
                "api-key": settings.RESEND_API_KEY,
                "Content-Type": "application/json",
            },
            json={
                "sender": _parse_sender(settings.SMTP_FROM),
                "to": [{"email": to_email}],
                "subject": "Reset your Unburden password",
                "htmlContent": html,
                "textContent": (
                    f"Reset your Unburden password:\n{reset_url}\n\n"
                    "This link expires in 1 hour."
                ),
            },
        )
        resp.raise_for_status()
