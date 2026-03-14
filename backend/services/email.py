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
    return {"name": "Ventigo", "email": smtp_from.strip()}


async def _send_email(
    to_email: str,
    subject: str,
    heading: str,
    body_text: str,
    cta_label: str,
    cta_url: str,
    expiry_note: str,
    fallback_label: str,
) -> None:
    """Shared Brevo email sender for transactional emails."""
    settings = get_settings()

    if not settings.BREVO_API_KEY:
        logger.warning(
            f"[DEV] BREVO_API_KEY not set. "
            f"{fallback_label} for {to_email}: {cta_url}"
        )
        return

    html = f"""
    <html>
    <body style="font-family:'Comfortaa',sans-serif;background:#FFF8F0;color:#3B3335;padding:40px;">
      <div style="max-width:480px;margin:auto;background:#FFFFFF;border-radius:16px;padding:40px;border:1px solid #F0E8EA;">
        <h2 style="color:#3B3335;margin-top:0;font-size:22px;letter-spacing:-0.02em;">{heading}</h2>
        <p style="font-size:15px;color:#4D4448;margin:0 0 24px;">{body_text}</p>
        <a href="{cta_url}"
           style="display:inline-block;padding:14px 28px;background:#F4A68C;color:#3B3335;
                  border-radius:12px;text-decoration:none;font-weight:700;font-size:15px;">
          {cta_label}
        </a>
        <p style="font-size:13px;color:#8A7F85;margin:28px 0 0;">
          {expiry_note}
        </p>
        <hr style="border:none;border-top:1px solid #F0E8EA;margin:24px 0;"/>
        <p style="font-size:11px;color:#8A7F85;">If you didn&rsquo;t request this, ignore this email.</p>
      </div>
    </body>
    </html>
    """

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            "https://api.brevo.com/v3/smtp/email",
            headers={
                "api-key": settings.BREVO_API_KEY,
                "Content-Type": "application/json",
            },
            json={
                "sender": _parse_sender(settings.SMTP_FROM),
                "to": [{"email": to_email}],
                "subject": subject,
                "htmlContent": html,
                "textContent": f"{body_text}\n{cta_url}\n\n{expiry_note}",
            },
        )
        resp.raise_for_status()


async def send_verification_email(to_email: str, verify_url: str) -> None:
    await _send_email(
        to_email=to_email,
        subject="Verify your Ventigo email",
        heading="Ventigo",
        body_text="One click to verify your email address:",
        cta_label="Verify my email &rarr;",
        cta_url=verify_url,
        expiry_note='This link expires in <strong style="color:#4D4448;">24 hours</strong>.',
        fallback_label="Verification link",
    )


async def send_password_reset_email(to_email: str, reset_url: str) -> None:
    await _send_email(
        to_email=to_email,
        subject="Reset your Ventigo password",
        heading="Ventigo",
        body_text="Click the button below to reset your password:",
        cta_label="Reset my password &rarr;",
        cta_url=reset_url,
        expiry_note='This link expires in <strong style="color:#4D4448;">1 hour</strong>.',
        fallback_label="Password reset link",
    )
