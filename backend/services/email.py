"""
Email service - sends transactional emails via the Resend API (https://resend.com).
Uses httpx (already a project dependency) - no extra packages needed.

Dev mode: if RESEND_API_KEY is not set, the verification link is printed to the
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
            f"[DEV] RESEND_API_KEY not set. "
            f"Verification link for {to_email}: {verify_url}"
        )
        return

    html = f"""
    <html>
    <body style="font-family:sans-serif;background:#0f0c1a;color:#f5f5f5;padding:40px;">
      <div style="max-width:480px;margin:auto;background:#1d1829;border-radius:16px;padding:40px;">
        <h2 style="color:#b8a4f4;margin-top:0;font-size:22px;letter-spacing:-0.02em;">Flow</h2>
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
        <p style="font-size:11px;color:#615c80;">If you didn't create a Flow account, ignore this email.</p>
      </div>
    </body>
    </html>
    """

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            "https://api.resend.com/emails",
            headers={"Authorization": f"Bearer {settings.RESEND_API_KEY}"},
            json={
                "from": settings.SMTP_FROM,
                "to": [to_email],
                "subject": "Verify your Flow email",
                "html": html,
                "text": (
                    f"Verify your Flow account:\n{verify_url}\n\n"
                    "This link expires in 24 hours."
                ),
            },
        )
        resp.raise_for_status()


async def send_otp_email(to_email: str, otp: str) -> None:
    settings = get_settings()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Your Varta verification code"
    msg["From"] = settings.SMTP_FROM
    msg["To"] = to_email

    plain = f"Your Varta one-time code is: {otp}\n\nThis code expires in {settings.OTP_EXPIRE_MINUTES} minutes.\nDo not share this code with anyone."

    html = f"""
    <html>
    <body style="font-family:sans-serif;background:#0f0f0f;color:#f5f5f5;padding:40px;">
      <div style="max-width:420px;margin:auto;background:#1a1a1a;border-radius:12px;padding:36px;">
        <h2 style="color:#a78bfa;margin-top:0;">Varta</h2>
        <p style="font-size:15px;color:#ccc;">Your one-time verification code:</p>
        <div style="font-size:42px;font-weight:700;letter-spacing:12px;color:#fff;margin:24px 0;">{otp}</div>
        <p style="font-size:13px;color:#888;">
          This code expires in <strong style="color:#ccc;">{settings.OTP_EXPIRE_MINUTES} minutes</strong>.
          <br/>Do not share this code with anyone.
        </p>
        <hr style="border:none;border-top:1px solid #333;margin:24px 0;"/>
        <p style="font-size:11px;color:#555;">If you did not request this, ignore this email.</p>
      </div>
    </body>
    </html>
    """

    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(html, "html"))

    await aiosmtplib.send(
        msg,
        hostname=settings.SMTP_HOST,
        port=settings.SMTP_PORT,
        username=settings.SMTP_USER,
        password=settings.SMTP_PASSWORD,
        start_tls=True,
    )
