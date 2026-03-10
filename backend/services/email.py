"""
Email service - sends transactional emails via the Brevo API (https://brevo.com).
Uses httpx (already a project dependency) - no extra packages needed.

Dev mode: if BREVO_API_KEY is not set, the verification link is printed to the
console so you can click it directly during local development.
"""

import logging
import httpx
from config import get_settings

logger = logging.getLogger(__name__)


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
    <body style="font-family:sans-serif;background:#0f0c1a;color:#f5f5f5;padding:40px;">
      <div style="max-width:480px;margin:auto;background:#1d1829;border-radius:16px;padding:40px;">
        <h2 style="color:#b8a4f4;margin-top:0;font-size:22px;letter-spacing:-0.02em;">Unburden</h2>
        <p style="font-size:15px;color:#c8c4e2;margin:0 0 24px;">One click to verify your email address:</p>
        <a href="{verify_url}"
           style="display:inline-block;padding:14px 28px;background:#b8a4f4;color:#0f0c1a;
                  border-radius:12px;text-decoration:none;font-weight:700;font-size:15px;">
          Verify my email &rarr;
        </a>
        <p style="font-size:13px;color:#615c80;margin:28px 0 0;">
          This link expires in <strong style="color:#9e9ab8;">24 hours</strong>.
        </p>
        <hr style="border:none;border-top:1px solid #2f2a42;margin:24px 0;"/>
        <p style="font-size:11px;color:#615c80;">If you didn't create an Unburden account, ignore this email.</p>
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
                "sender": {"name": "Unburden", "email": settings.SMTP_FROM},
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
