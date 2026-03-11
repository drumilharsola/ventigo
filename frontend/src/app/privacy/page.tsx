"use client";

import { brand } from "@/lib/brand";

export default function PrivacyPolicyPage() {
  return (
    <main
      style={{
        maxWidth: 720,
        margin: "0 auto",
        padding: "48px 24px",
        color: "var(--ink)",
        lineHeight: 1.7,
      }}
    >
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Privacy Policy
      </h1>
      <p style={{ color: "var(--slate)", marginBottom: 32, fontSize: 14 }}>
        Last updated: {new Date().toISOString().slice(0, 10)}
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>1. Who We Are</h2>
        <p>
          {brand.appName} is an anonymous peer-support platform that connects people
          for real-time, one-on-one conversations. Your privacy is fundamental to our
          mission.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>2. Data We Collect</h2>
        <p>We collect the <strong>minimum data</strong> necessary to operate the service:</p>
        <ul style={{ paddingLeft: 24, marginTop: 8 }}>
          <li>Email address (for authentication and verification only)</li>
          <li>Date of birth (age verification; not stored after check)</li>
          <li>Randomly generated username and selected avatar</li>
          <li>Chat messages (temporarily stored, auto-deleted after 7 days)</li>
          <li>Abuse reports you submit</li>
        </ul>
        <p style={{ marginTop: 8 }}>
          We do <strong>not</strong> collect real names, phone numbers, location data,
          or any personally identifiable information beyond your email.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>3. Data Retention</h2>
        <p>
          All chat data (rooms, messages) is automatically deleted after <strong>7 days</strong>.
          Account profiles persist as long as your account exists. You may delete your
          account at any time, which permanently removes all associated data.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>4. Data Sharing</h2>
        <p>
          We do <strong>not</strong> sell, rent, or share your personal data with third
          parties. We do not display ads. We do not use tracking pixels or analytics
          cookies.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>5. Your Rights (GDPR)</h2>
        <p>Under GDPR and similar privacy laws, you have the right to:</p>
        <ul style={{ paddingLeft: 24, marginTop: 8 }}>
          <li><strong>Access:</strong> Export all your data from the Profile page.</li>
          <li><strong>Erasure:</strong> Delete your account and all associated data permanently.</li>
          <li><strong>Rectification:</strong> Update your avatar or re-roll your username at any time.</li>
          <li><strong>Portability:</strong> Download your data in JSON format.</li>
        </ul>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>6. Security</h2>
        <p>
          All data is transmitted over HTTPS. Passwords are hashed using bcrypt.
          Sessions are managed via signed JWTs. We apply rate limiting and input
          sanitization to prevent abuse.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>7. Contact</h2>
        <p>
          For privacy-related inquiries, contact us at{" "}
          <strong>{brand.supportEmail || "support@example.com"}</strong>.
        </p>
      </section>
    </main>
  );
}
