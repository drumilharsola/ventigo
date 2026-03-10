"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";
import { FlowLogo } from "@/components/FlowLogo";

type Mode = "login" | "register" | "check-email";

export default function VerifyPage() {
  const router = useRouter();
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
      <div style={{
        display: "grid", gridTemplateColumns: "1fr 1fr",
        minHeight: "100vh", width: "100%",
        position: "relative", zIndex: 5,
      }}>
        <div className="orb orb-a" style={{ position: "fixed" }} />
        <div className="orb orb-b" style={{ position: "fixed" }} />

        {/* LEFT: Quote panel */}
        <div style={{
          padding: "60px 64px",
          display: "flex", flexDirection: "column", justifyContent: "space-between",
          borderRight: "1px solid rgba(255,255,255,0.06)",
          position: "relative", zIndex: 5,
        }}>
          <FlowLogo />
          <div>
            <p style={{
              fontFamily: "var(--font-display)",
              fontSize: "clamp(24px, 3vw, 38px)",
              fontWeight: 400, fontStyle: "italic",
              color: "var(--white)", lineHeight: 1.3,
              letterSpacing: "-0.02em", marginBottom: 24,
            }}>
              &ldquo;Give sorrow words; the grief that does not{" "}
              <em style={{ fontStyle: "normal", color: "var(--accent)" }}>speak</em>,
              whispers the o&apos;er-fraught heart, and bids it break.&rdquo;
            </p>
            <p style={{ fontSize: 12, fontWeight: 300, color: "var(--slate)", letterSpacing: "0.06em" }}>
              - Shakespeare, <em style={{ fontStyle: "normal" }}>Macbeth</em>, Act IV
            </p>
          </div>
          <p className="t-label" style={{ color: "var(--graphite)", fontSize: 11 }}>Anonymous by design.</p>
        </div>

        {/* RIGHT: Form panel */}
        <div style={{
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
                <span onClick={() => switchMode("register")} style={{ color: "var(--accent)", cursor: "pointer" }}>
                  Create one →
                </span>
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
                A verification link will be sent to your email.
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
                <span onClick={() => switchMode("login")} style={{ color: "var(--accent)", cursor: "pointer" }}>
                  Sign in →
                </span>
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
                Click it to unlock the anchor role.
              </p>
              <p style={{ fontSize: 13, fontWeight: 300, color: "var(--slate)", marginBottom: 40, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                You can still set up your profile and vent in the meantime.
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
