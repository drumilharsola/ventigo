"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { FlowLogo } from "@/components/FlowLogo";

const STEPS = [
  {
    num: "01",
    icon: "💬",
    title: "Vent freely.",
    body: "There are no wrong words here. Say exactly what you're feeling - without judgment, without consequences.",
  },
  {
    num: "02",
    icon: "🫂",
    title: "Be an anchor.",
    body: "You can choose to support someone instead. Your only job? Listen. No advice needed - just presence.",
  },
  {
    num: "03",
    icon: "⏱",
    title: "15 minutes.",
    body: "Sessions last 15 minutes. Enough time to be heard, short enough to feel safe. You can extend if you both agree.",
  },
  {
    num: "04",
    icon: "🔒",
    title: "No trace.",
    body: "Anonymous by default. No names, no history shared outside the room. What's said here stays here.",
  },
];

export default function OnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const current = STEPS[step];
  const isLast = step === STEPS.length - 1;

  return (
    <div className="dark-canvas grain" style={{ minHeight: "100vh", display: "flex", flexDirection: "column", position: "relative" }}>
      <div className="orb orb-a" />
      <div className="orb orb-b" />
      <div className="orb orb-c" />

      {/* Nav */}
      <div style={{ padding: "24px 32px", position: "relative", zIndex: 10 }}>
        <FlowLogo />
      </div>

      {/* Content */}
      <div style={{
        flex: 1, display: "flex", flexDirection: "column",
        alignItems: "center", justifyContent: "center",
        padding: "32px 24px 60px",
        position: "relative", zIndex: 5,
      }}>
        {/* Step dots */}
        <div style={{ display: "flex", gap: 8, marginBottom: 48 }}>
          {STEPS.map((_, i) => (
            <div key={i} style={{
              width: i === step ? 24 : 8, height: 8,
              borderRadius: 999,
              background: i === step ? "var(--accent)" : i < step ? "rgba(184,160,232,0.4)" : "rgba(255,255,255,0.1)",
              transition: "all 0.4s",
            }} />
          ))}
        </div>

        {/* Card */}
        <div className="glass-card" style={{ maxWidth: 480, width: "100%", padding: "48px 40px", textAlign: "center" }}>
          <p style={{ fontSize: 48, marginBottom: 16 }}>{current.icon}</p>
          <p className="t-label" style={{ color: "var(--accent)", marginBottom: 8 }}>{current.num}</p>
          <h2 style={{
            fontFamily: "var(--font-display)",
            fontSize: "clamp(28px,5vw,40px)",
            fontWeight: 700, color: "var(--white)",
            letterSpacing: "-0.025em", marginBottom: 16, lineHeight: 1.15,
          }}>
            {current.title}
          </h2>
          <p style={{
            fontSize: 15, fontWeight: 300, color: "var(--slate)",
            lineHeight: 1.7, fontFamily: "var(--font-ui)", marginBottom: 40,
          }}>
            {current.body}
          </p>

          <div style={{ display: "flex", gap: 10, justifyContent: "center" }}>
            {step > 0 && (
              <button
                onClick={() => setStep(step - 1)}
                className="btn btn-ghost btn-md"
              >
                Back
              </button>
            )}
            <button
              onClick={() => isLast ? router.push("/lobby") : setStep(step + 1)}
              className="btn btn-accent btn-md"
            >
              {isLast ? "Enter Flow →" : "Next →"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
