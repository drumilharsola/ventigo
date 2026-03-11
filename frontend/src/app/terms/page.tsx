"use client";

import { brand } from "@/lib/brand";

export default function TermsOfServicePage() {
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
        Terms of Service
      </h1>
      <p style={{ color: "var(--slate)", marginBottom: 32, fontSize: 14 }}>
        Last updated: {new Date().toISOString().slice(0, 10)}
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>1. Acceptance</h2>
        <p>
          By using {brand.appName}, you agree to these Terms of Service. If you do not
          agree, please do not use the service.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>2. Eligibility</h2>
        <p>
          You must be at least <strong>18 years old</strong> to use {brand.appName}.
          By creating an account, you confirm you meet this age requirement.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>3. Acceptable Use</h2>
        <p>You agree not to:</p>
        <ul style={{ paddingLeft: 24, marginTop: 8 }}>
          <li>Harass, threaten, or abuse other users</li>
          <li>Share illegal, harmful, or explicit content</li>
          <li>Impersonate others or create fake accounts</li>
          <li>Attempt to circumvent anonymity to identify other users</li>
          <li>Use the platform for spam, advertising, or recruitment</li>
          <li>Exploit vulnerabilities or disrupt the service</li>
        </ul>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>4. Anonymity</h2>
        <p>
          {brand.appName} is designed around anonymity. You are assigned a random
          username and are not required to provide real identity information beyond
          an email address for account verification.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>5. Moderation</h2>
        <p>
          We reserve the right to suspend or terminate accounts that violate these
          terms. Users may report abuse, and reports are reviewed by platform
          moderators.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>6. Disclaimer</h2>
        <p>
          {brand.appName} is <strong>not</strong> a substitute for professional mental
          health care. If you are in crisis, please contact a local emergency service
          or mental health hotline. The platform is provided &ldquo;as is&rdquo; without
          warranties of any kind.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>7. Limitation of Liability</h2>
        <p>
          To the maximum extent permitted by law, {brand.appName} and its operators
          shall not be liable for any indirect, incidental, or consequential damages
          arising from your use of the service.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>8. Changes</h2>
        <p>
          We may update these terms from time to time. Continued use of the service
          after changes constitutes acceptance of the updated terms.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>9. Contact</h2>
        <p>
          Questions about these terms? Contact us at{" "}
          <strong>{brand.supportEmail || "support@example.com"}</strong>.
        </p>
      </section>
    </main>
  );
}
