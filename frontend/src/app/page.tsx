"use client";

import Link from "next/link";
import { useAuthStore } from "@/store/authStore";
import { FlowLogo } from "@/components/FlowLogo";

const MARQUEE_ITEMS = [
  "Unburden in 15 minutes", "Completely anonymous", "No stored messages",
  "Real humans only", "No advice, just presence", "Disappears in 7 days",
];

const FEATURES = [
  { num: "01", title: "Unburden yourself", desc: "Say what’s weighing on you without names, judgment, or consequences." },
  { num: "02", title: "Be a steady presence", desc: "Show up for someone with calm attention. No advice needed." },
  { num: "03", title: "15 minutes", desc: "Still enough to matter. Short enough to stay safe. The timer keeps it bounded." },
  { num: "04", title: "No trace", desc: "Sessions disappear. Words fade. Identity vanishes after 7 days." },
];

const doubled = [...MARQUEE_ITEMS, ...MARQUEE_ITEMS];

export default function HomePage() {
  const { token, username } = useAuthStore();
  const authed = Boolean(token && username);

  return (
    <div className="grain" style={{ minHeight: "100vh", background: "var(--ink)", overflow: "hidden" }}>
      <div className="dark-canvas" style={{ minHeight: "100vh", overflow: "visible" }}>
        <div className="orb orb-a" />
        <div className="orb orb-b" />
        <div className="orb orb-c" />
        <div className="orb orb-d" />

        {/* Nav */}
        <nav style={{
          position: "relative", zIndex: 10,
          padding: "28px 48px",
          display: "flex", alignItems: "center", justifyContent: "space-between",
        }}>
          <FlowLogo />
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <span className="t-label" style={{ color: "var(--slate)" }}>
              Anonymous · Ephemeral · Human
            </span>
            {authed ? (
              <Link href="/lobby" className="btn btn-primary btn-md">Open board</Link>
            ) : (
              <Link href="/verify" className="btn btn-primary btn-md">Get started</Link>
            )}
          </div>
        </nav>

        {/* Hero */}
        <section style={{
          position: "relative", zIndex: 5,
          minHeight: "calc(100vh - 100px)",
          display: "flex", flexDirection: "column", justifyContent: "center",
          padding: "0 48px 80px",
          maxWidth: 1100,
        }}>
          <div style={{ marginBottom: 32 }}>
            <div className="pill pill-accent">
              <span className="pill-dot" />
              Open · Safe · No history
            </div>
          </div>
          <h1 style={{
            fontFamily: "var(--font-display)",
            fontSize: "clamp(64px, 10vw, 130px)",
            fontWeight: 900,
            lineHeight: 0.92,
            letterSpacing: "-0.04em",
            color: "var(--white)",
            marginBottom: 36,
          }}>
            Unburden<br />
            <em style={{
              fontStyle: "italic",
              background: "linear-gradient(135deg, var(--flow-1), var(--flow-2))",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
              backgroundClip: "text",
            }}>yourself.</em>
          </h1>
          <p style={{
            fontSize: 18, fontWeight: 300,
            color: "var(--fog)", lineHeight: 1.7,
            maxWidth: 480, marginBottom: 52,
            fontFamily: "var(--font-ui)",
          }}>
            Find a real human who will sit with you - no names, no records, no advice unless you want it.
            Just fifteen minutes of honest presence.
          </p>
          <div style={{ display: "flex", gap: 14, alignItems: "center", flexWrap: "wrap" }}>
            <Link
              href={authed ? "/lobby" : "/verify"}
              className="btn btn-primary btn-lg"
            >
              I need to vent →
            </Link>
            <Link
              href={authed ? "/lobby" : "/verify"}
              className="btn btn-ghost btn-lg"
            >
              I&apos;ll be someone&apos;s anchor
            </Link>
          </div>
        </section>

        {/* Marquee */}
        <div style={{
          position: "relative", zIndex: 5,
          overflow: "hidden",
          borderTop: "1px solid rgba(255,255,255,0.05)",
          borderBottom: "1px solid rgba(255,255,255,0.05)",
          padding: "16px 0",
        }}>
          <div style={{
            display: "flex", gap: 48,
            animation: "marquee 22s linear infinite",
            width: "max-content",
          }}>
            {doubled.map((item, i) => (
              <div key={i} style={{
                display: "flex", alignItems: "center", gap: 16,
                whiteSpace: "nowrap",
                fontFamily: "var(--font-ui)",
                fontSize: 12, fontWeight: 600,
                letterSpacing: "0.1em", textTransform: "uppercase",
                color: "rgba(255,255,255,0.2)",
              }}>
                <span style={{ width: 4, height: 4, borderRadius: "50%", background: "var(--accent)", opacity: 0.5, flexShrink: 0 }} />
                {item}
              </div>
            ))}
          </div>
        </div>

        {/* Features strip */}
        <div style={{
          position: "relative", zIndex: 5,
          display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
          borderTop: "1px solid rgba(255,255,255,0.06)",
        }}>
          {FEATURES.map((f, i) => (
            <div key={f.num} style={{
              padding: "48px 40px",
              borderRight: i < 3 ? "1px solid rgba(255,255,255,0.06)" : "none",
            }}>
              <div style={{
                fontFamily: "var(--font-display)",
                fontSize: 11, fontWeight: 400,
                color: "var(--accent)", marginBottom: 20, opacity: 0.7,
              }}>{f.num}</div>
              <div style={{
                fontFamily: "var(--font-display)",
                fontSize: 20, fontWeight: 700,
                color: "var(--white)", marginBottom: 12,
                lineHeight: 1.2, letterSpacing: "-0.01em",
              }}>{f.title}</div>
              <p style={{
                fontSize: 13, fontWeight: 300,
                color: "var(--slate)", lineHeight: 1.65,
                fontFamily: "var(--font-ui)",
              }}>{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
