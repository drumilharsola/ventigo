"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { api } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";
import { FlowLogo } from "@/components/FlowLogo";

type Mode = "login" | "register" | "check-email";

const QUOTES = [
  {
    text: "Give sorrow words; the grief that does not speak whispers the o'er-fraught heart, and bids it break.",
    author: "William Shakespeare",
    source: "Macbeth",
  },
  {
    text: "To weep is to make less the depth of grief.",
    author: "William Shakespeare",
    source: "Henry VI, Part III",
  },
  {
    text: "When sorrows come, they come not single spies, but in battalions.",
    author: "William Shakespeare",
    source: "Hamlet",
  },
  {
    text: "The robbed that smiles steals something from the thief.",
    author: "William Shakespeare",
    source: "Othello",
  },
  {
    text: "Hope smiles from the threshold of the year to come, whispering, 'It will be happier.'",
    author: "Alfred, Lord Tennyson",
    source: "In Memoriam A.H.H.",
  },
  {
    text: "Ring out the grief that saps the mind, for those that here we see no more.",
    author: "Alfred, Lord Tennyson",
    source: "In Memoriam A.H.H.",
  },
  {
    text: "Be not afraid of life. Believe that life is worth living, and your belief will help create the fact.",
    author: "William James",
    source: "The Will to Believe",
  },
  {
    text: "Nothing can bring you peace but yourself.",
    author: "Ralph Waldo Emerson",
    source: "Self-Reliance",
  },
  {
    text: "Earth's crammed with heaven, and every common bush afire with God.",
    author: "Elizabeth Barrett Browning",
    source: "Aurora Leigh",
  },
  {
    text: "I am not afraid of storms, for I am learning how to sail my ship.",
    author: "Louisa May Alcott",
    source: "Little Women",
  },
  {
    text: "The soul would have no rainbow had the eyes no tears.",
    author: "John Vance Cheney",
    source: "Tears",
  },
  {
    text: "I dwell in Possibility.",
    author: "Emily Dickinson",
    source: "Poems by Emily Dickinson",
  },
  {
    text: "The best way out is always through.",
    author: "Robert Frost",
    source: "A Servant to Servants",
  },
  {
    text: "Although the world is full of suffering, it is also full of the overcoming of it.",
    author: "Helen Keller",
    source: "Optimism",
  },
  {
    text: "What do we live for, if it is not to make life less difficult for each other?",
    author: "George Eliot",
    source: "Middlemarch",
  },
  {
    text: "What we call our despair is often only the painful eagerness of unfed hope.",
    author: "George Eliot",
    source: "Middlemarch",
  },
  {
    text: "There is no despair so absolute as that which comes with the first moments of our first great sorrow.",
    author: "George Eliot",
    source: "Adam Bede",
  },
  {
    text: "Knowledge of what is possible is the beginning of happiness.",
    author: "George Santayana",
    source: "The Life of Reason",
  },
  {
    text: "A loving heart is the truest wisdom.",
    author: "Charles Dickens",
    source: "David Copperfield",
  },
  {
    text: "The sun himself is weak when he first rises, and gathers strength and courage as the day gets on.",
    author: "Charles Dickens",
    source: "The Old Curiosity Shop",
  },
  {
    text: "Pause you who read this, and think of the long chain of iron or gold, of thorns or flowers, that would never have bound you, but for the formation of the first link on one memorable day.",
    author: "Charles Dickens",
    source: "Great Expectations",
  },
  {
    text: "If we could read the secret history of our enemies, we should find in each man's life sorrow and suffering enough to disarm all hostility.",
    author: "Henry Wadsworth Longfellow",
    source: "Hyperion",
  },
];

const OFFER_ITEMS = [
  {
    title: "Anonymous",
    body: "Come in without your real name. Just be yourself here.",
  },
  {
    title: "Private",
    body: "Each conversation is one-to-one, with no public room and no audience.",
  },
  {
    title: "Gentle and short",
    body: "A session lasts 15 minutes, so it stays light enough to enter and leave.",
  },
];

function VerifyContent() {
  const router = useRouter();
  const params = useSearchParams();
  const { setAuth, setEmailVerified, setProfile } = useAuthStore();

  const [mode, setMode] = useState<Mode>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [resendLoading, setResendLoading] = useState(false);
  const [resendDone, setResendDone] = useState(false);
  const [pendingToken, setPendingToken] = useState<string | null>(null);
  const [quoteIndex, setQuoteIndex] = useState<number | null>(null);

  useEffect(() => {
    setQuoteIndex(Math.floor(Math.random() * QUOTES.length));
  }, []);

  const activeQuote = quoteIndex === null ? null : QUOTES[quoteIndex];

  const headingStyle: React.CSSProperties = {
    fontFamily: "var(--font-display)",
    fontSize: 36, fontWeight: 700, color: "var(--white)",
    letterSpacing: "-0.025em", marginBottom: 8, lineHeight: 1.15,
  };

  const labelStyle: React.CSSProperties = {
    display: "block", fontSize: 11, fontWeight: 600,
    letterSpacing: "0.1em", textTransform: "uppercase",
    color: "var(--slate)", marginBottom: 10, fontFamily: "var(--font-ui)",
  };

  const errorEl = error ? (
    <p style={{
      fontSize: 13, color: "var(--danger)",
      background: "rgba(232,128,128,0.08)",
      border: "1px solid rgba(232,128,128,0.2)",
      borderRadius: "var(--r-md)", padding: "10px 14px",
    }}>{error}</p>
  ) : null;

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await api.login(email.trim().toLowerCase(), password);
      setAuth(res.token, res.session_id);
      setEmailVerified(res.email_verified);
      if (res.has_profile) {
        const me = await api.getMe(res.token);
        setProfile(me.username, Number(me.avatar_id ?? 0));
        router.push("/lobby");
      } else {
        router.push("/profile");
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (password !== confirmPassword) {
      setError("Passwords don't match");
      return;
    }
    setLoading(true);
    try {
      const res = await api.register(email.trim().toLowerCase(), password);
      setAuth(res.token, res.session_id);
      setEmailVerified(false);
      setPendingToken(res.token);
      setMode("check-email");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Registration failed");
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (!pendingToken) return;
    setResendLoading(true);
    setResendDone(false);
    try {
      await api.sendVerification(pendingToken);
      setResendDone(true);
    } catch { /* swallow */ }
    finally { setResendLoading(false); }
  };

  const switchMode = (next: Mode) => {
    setMode(next);
    setError("");
    setPassword("");
    setConfirmPassword("");
  };

  return (
    <div className="grain" style={{ minHeight: "100vh", background: "var(--ink)", display: "flex" }}>
      <div className="verify-shell" style={{
        display: "grid", gridTemplateColumns: "1fr 1fr",
        minHeight: "100vh", width: "100%",
        position: "relative", zIndex: 5,
      }}>
        <div className="orb orb-a" style={{ position: "fixed" }} />
        <div className="orb orb-b" style={{ position: "fixed" }} />

        {/* LEFT: Quote panel */}
        <div className="quote-panel" style={{
          padding: "60px 64px",
          display: "flex", flexDirection: "column", justifyContent: "space-between",
          borderRight: "1px solid rgba(255,255,255,0.06)",
          position: "relative", zIndex: 5,
        }}>
          <FlowLogo />
          <div style={{ display: "flex", flexDirection: "column", gap: 28 }}>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              <span className="pill pill-accent" style={{ marginBottom: 18 }}>
                Anonymous. Private. Human.
              </span>
              <p style={{
                fontFamily: "var(--font-display)",
                fontSize: "clamp(28px, 3.5vw, 42px)",
                fontWeight: 400,
                fontStyle: "italic",
                color: "var(--white)",
                lineHeight: 1.28,
                letterSpacing: "-0.02em",
                marginBottom: 0,
              }} suppressHydrationWarning>
                {activeQuote ? `“${activeQuote.text}”` : ""}
              </p>
              <p style={{ fontSize: 12, fontWeight: 300, color: "var(--slate)", letterSpacing: "0.06em", textTransform: "uppercase", fontFamily: "var(--font-ui)", minHeight: 18 }} suppressHydrationWarning>
                {activeQuote ? `${activeQuote.author} · ${activeQuote.source}` : ""}
              </p>
            </div>

            <div className="glass-card" style={{ padding: "18px 20px" }}>
              <p className="t-label" style={{ marginBottom: 10 }}>What we offer</p>
              <div style={{ display: "grid", gap: 14 }}>
                {OFFER_ITEMS.map((item) => (
                  <div key={item.title}>
                    <p style={{ margin: "0 0 4px", fontSize: 14, fontWeight: 600, color: "var(--white)", fontFamily: "var(--font-ui)" }}>
                      {item.title}
                    </p>
                    <p style={{ margin: 0, fontSize: 13, color: "var(--fog)", lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                      {item.body}
                    </p>
                  </div>
                ))}
              </div>
            </div>

            <div>
              <p style={{
                fontFamily: "var(--font-display)",
                fontSize: "clamp(20px, 2.2vw, 30px)",
                fontWeight: 700,
                color: "var(--white)",
                lineHeight: 1.15,
                letterSpacing: "-0.02em",
                marginBottom: 10,
              }}>
                Speak without holding back.
              </p>
              <p style={{ fontSize: 14, fontWeight: 300, color: "var(--fog)", lineHeight: 1.7, maxWidth: 420, fontFamily: "var(--font-ui)" }}>
                You will be matched with one steady person for a short anonymous conversation.
              </p>
            </div>
          </div>
          <p className="t-label" style={{ color: "var(--graphite)", fontSize: 11 }}>Anonymous. Safe. Human.</p>
        </div>

        {/* RIGHT: Form panel */}
        <div className="form-panel" style={{
          padding: "60px 64px",
          display: "flex", flexDirection: "column", justifyContent: "center",
          position: "relative", zIndex: 5,
        }}>

          {/* ── Login ── */}
          {mode === "login" && (
            <>
              <div style={{ display: "flex", gap: 6, marginBottom: 48 }}>
                {[0, 1, 2].map((i) => (
                  <div key={i} style={{
                    height: 2, flex: 1, borderRadius: 2,
                    background: i === 0 ? "rgba(184,164,244,0.5)" : "rgba(255,255,255,0.1)",
                    transition: "all 0.4s",
                  }} />
                ))}
              </div>

              <h2 style={headingStyle}>Welcome<br />back.</h2>
              <p style={{ fontSize: 14, fontWeight: 300, color: "var(--slate)", marginBottom: 40, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                Sign in to continue.
              </p>

              <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                <div>
                  <label style={labelStyle}>Email</label>
                  <input className="flow-input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus placeholder="you@example.com" />
                </div>
                <div>
                  <label style={labelStyle}>Password</label>
                  <input className="flow-input" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required placeholder="••••••••" />
                </div>
                {errorEl}
                <button
                  type="submit" disabled={loading || !email.includes("@") || !password}
                  className="btn btn-accent btn-lg"
                  style={{ width: "100%", borderRadius: "var(--r-md)", opacity: loading || !email.includes("@") || !password ? 0.5 : 1 }}
                >
                  {loading ? "Signing in…" : "Sign in →"}
                </button>
              </form>

              <p style={{ textAlign: "center", fontSize: 13, color: "var(--slate)", marginTop: 28, fontFamily: "var(--font-ui)" }}>
                No account?{" "}
                <button type="button" onClick={() => switchMode("register")} style={{ color: "var(--accent)", cursor: "pointer", background: "none", border: "none", font: "inherit" }}>
                  Create one →
                </button>
              </p>
            </>
          )}

          {/* ── Register ── */}
          {mode === "register" && (
            <>
              <div style={{ display: "flex", gap: 6, marginBottom: 48 }}>
                {[0, 1, 2].map((i) => (
                  <div key={i} style={{
                    height: 2, flex: 1, borderRadius: 2,
                    background: i <= 1 ? "rgba(184,164,244,0.5)" : "rgba(255,255,255,0.1)",
                    transition: "all 0.4s",
                  }} />
                ))}
              </div>

              <h2 style={headingStyle}>Create<br />your account.</h2>
              <p style={{ fontSize: 14, fontWeight: 300, color: "var(--slate)", marginBottom: 40, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                A verification link will be sent to your email so you can fully unlock the keeper role.
              </p>

              <form onSubmit={handleRegister} style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                <div>
                  <label style={labelStyle}>Email</label>
                  <input className="flow-input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus placeholder="you@example.com" />
                </div>
                <div>
                  <label style={labelStyle}>Password</label>
                  <input className="flow-input" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required placeholder="At least 8 characters" />
                </div>
                <div>
                  <label style={labelStyle}>Confirm password</label>
                  <input className="flow-input" type="password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} required placeholder="••••••••" />
                </div>
                {errorEl}
                <button
                  type="submit"
                  disabled={loading || !email.includes("@") || password.length < 8 || !confirmPassword}
                  className="btn btn-accent btn-lg"
                  style={{ width: "100%", borderRadius: "var(--r-md)", opacity: loading || !email.includes("@") || password.length < 8 || !confirmPassword ? 0.5 : 1 }}
                >
                  {loading ? "Creating account…" : "Create account →"}
                </button>
              </form>

              <p style={{ textAlign: "center", fontSize: 11, color: "rgba(255,255,255,0.2)", marginTop: 20, fontFamily: "var(--font-ui)" }}>
                By continuing you confirm you are 18 or older.
              </p>
              <p style={{ textAlign: "center", fontSize: 13, color: "var(--slate)", marginTop: 12, fontFamily: "var(--font-ui)" }}>
                Already have an account?{" "}
                <button type="button" onClick={() => switchMode("login")} style={{ color: "var(--accent)", cursor: "pointer", background: "none", border: "none", font: "inherit" }}>
                  Sign in →
                </button>
              </p>
            </>
          )}

          {/* ── Check email ── */}
          {mode === "check-email" && (
            <>
              <div style={{ display: "flex", gap: 6, marginBottom: 48 }}>
                {[0, 1, 2].map((i) => (
                  <div key={i} style={{
                    height: 2, flex: 1, borderRadius: 2,
                    background: i <= 1 ? "var(--accent)" : "rgba(255,255,255,0.1)",
                    transition: "all 0.4s",
                  }} />
                ))}
              </div>

              <div style={{
                width: 56, height: 56, borderRadius: "50%",
                background: "var(--accent-dim)", border: "1px solid var(--accent-glow)",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 24, marginBottom: 28,
              }}>
                ✉️
              </div>

              <h2 style={headingStyle}>Check<br />your inbox.</h2>
              <p style={{ fontSize: 14, fontWeight: 300, color: "var(--slate)", marginBottom: 12, lineHeight: 1.7, fontFamily: "var(--font-ui)" }}>
                We sent a verification link to{" "}
                <span style={{ color: "var(--fog)" }}>{email}</span>.
                Click it to unlock the listner role.
              </p>
              <p style={{ fontSize: 13, fontWeight: 300, color: "var(--slate)", marginBottom: 40, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                You can still set up your profile and start venting in the meantime.
              </p>

              <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                <button
                  onClick={() => router.push("/profile")}
                  className="btn btn-accent btn-lg"
                  style={{ width: "100%", borderRadius: "var(--r-md)" }}
                >
                  Set up profile →
                </button>

                <button
                  onClick={handleResend}
                  disabled={resendLoading || resendDone}
                  className="btn btn-ghost btn-md"
                  style={{ width: "100%", borderRadius: "var(--r-md)", opacity: resendLoading || resendDone ? 0.6 : 1 }}
                >
                  {resendDone ? "Email sent ✓" : resendLoading ? "Sending…" : "Resend link"}
                </button>
              </div>
            </>
          )}

        </div>
      </div>
    </div>
  );
}

export default function VerifyPage() {
  return (
    <Suspense fallback={<div style={{ minHeight: "100vh", background: "var(--ink)" }} />}>
      <VerifyContent />
    </Suspense>
  );
}
