"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";
import { AVATARS, avatarUrl } from "@/lib/avatars";
import { FlowLogo } from "@/components/FlowLogo";

const ALL_AVATARS = [...AVATARS];

export default function ProfilePage() {
  const router = useRouter();
  const { token, setProfile } = useAuthStore();

  const [dob, setDob] = useState("");
  const [avatarId, setAvatarId] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!token) router.push("/verify");
  }, [token, router]);

  const maxDob = (() => {
    const d = new Date();
    d.setFullYear(d.getFullYear() - 18);
    return d.toISOString().split("T")[0];
  })();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (!dob) return;
    setLoading(true);
    try {
      const result = await api.setProfile(token!, { dob, avatar_id: avatarId });
      setProfile(result.username, result.avatar_id);
      router.push("/lobby");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to save profile");
    } finally {
      setLoading(false);
    }
  };

  const selectedAvatar = ALL_AVATARS.find((a) => a.id === avatarId) ?? ALL_AVATARS[0];

  return (
    <div className="grain" style={{ minHeight: "100vh", background: "var(--ink)", display: "flex" }}>
      <div style={{
        display: "grid", gridTemplateColumns: "1fr 1fr",
        minHeight: "100vh", width: "100%",
        position: "relative", zIndex: 5,
      }}>
        {/* Orbs */}
        <div className="orb orb-a" style={{ position: "fixed" }} />
        <div className="orb orb-c" style={{ position: "fixed" }} />

        {/* LEFT: Live preview */}
        <div style={{
          padding: "60px 64px",
          display: "flex", flexDirection: "column",
          justifyContent: "space-between",
          borderRight: "1px solid rgba(255,255,255,0.06)",
          position: "relative", zIndex: 5,
        }}>
          <FlowLogo />
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 20, textAlign: "center" }}>
            <div style={{
              position: "relative", display: "inline-block",
            }}>
              <div style={{
                width: 140, height: 140,
                borderRadius: "50%",
                background: "var(--accent-glow)",
                border: "2px solid rgba(184,160,232,0.3)",
                overflow: "hidden",
                boxShadow: "0 0 48px rgba(184,160,232,0.18)",
                transition: "all 0.3s",
              }}>
                <img
                  src={avatarUrl(selectedAvatar, 140)}
                  alt="Your avatar"
                  width={140} height={140}
                  style={{ display: "block", width: "100%", borderRadius: "50%" }}
                />
              </div>
            </div>
            <div>
              <p style={{
                fontFamily: "var(--font-display)",
                fontSize: 22, fontWeight: 400, fontStyle: "italic",
                color: "var(--fog)",
              }}>This is you.</p>
              <p className="t-label" style={{ color: "var(--slate)", marginTop: 6 }}>
                Your username will be revealed after setup.
              </p>
            </div>
          </div>
          <p className="t-label" style={{ color: "var(--graphite)", fontSize: 11 }}>
            Anonymous by design.
          </p>
        </div>

        {/* RIGHT: Form */}
        <div style={{
          padding: "60px 64px",
          display: "flex", flexDirection: "column", justifyContent: "center",
          position: "relative", zIndex: 5, overflowY: "auto",
        }}>
          {/* Step bar */}
          <div style={{ display: "flex", gap: 6, marginBottom: 48 }}>
            {[0, 1, 2].map((i) => (
              <div key={i} style={{
                height: 2, flex: 1, borderRadius: 2,
                background: i < 2 ? "rgba(184,160,232,0.5)"
                  : i === 2 ? "var(--accent)"
                  : "rgba(255,255,255,0.1)",
                transition: "all 0.4s",
              }} />
            ))}
          </div>

          <h2 style={{
            fontFamily: "var(--font-display)",
            fontSize: 36, fontWeight: 700, color: "var(--white)",
            letterSpacing: "-0.025em", marginBottom: 8, lineHeight: 1.15,
          }}>
            Set up your<br /><em style={{ color: "var(--accent)" }}>profile.</em>
          </h2>
          <p style={{
            fontSize: 14, fontWeight: 300, color: "var(--slate)",
            marginBottom: 36, lineHeight: 1.6, fontFamily: "var(--font-ui)",
          }}>
            Just a few details - then we can get you into the room.
          </p>

          <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: 28 }}>
            <div>
              <label style={{
                display: "block", fontSize: 11, fontWeight: 600,
                letterSpacing: "0.1em", textTransform: "uppercase",
                color: "var(--slate)", marginBottom: 10, fontFamily: "var(--font-ui)",
              }}>
                Date of birth <span style={{ fontWeight: 300, color: "var(--graphite)", textTransform: "none", letterSpacing: 0 }}>(18+ only)</span>
              </label>
              <input
                className="flow-input"
                type="date"
                value={dob}
                onChange={(e) => setDob(e.target.value)}
                max={maxDob}
                required
                style={{ colorScheme: "dark" }}
              />
            </div>

            <div>
              <label style={{
                display: "block", fontSize: 11, fontWeight: 600,
                letterSpacing: "0.1em", textTransform: "uppercase",
                color: "var(--slate)", marginBottom: 14, fontFamily: "var(--font-ui)",
              }}>Choose your avatar</label>
              <div style={{
                display: "grid",
                gridTemplateColumns: "repeat(8, 1fr)",
                gap: 10,
              }}>
                {ALL_AVATARS.map((av) => {
                  const selected = avatarId === av.id;
                  return (
                    <button
                      key={av.id}
                      type="button"
                      onClick={() => setAvatarId(av.id)}
                      style={{
                        padding: 3, borderRadius: "50%",
                        border: `2px solid ${selected ? "var(--accent)" : "transparent"}`,
                        background: selected ? "var(--accent-glow)" : "transparent",
                        cursor: "pointer", transition: "all 0.15s",
                        boxShadow: selected ? "0 0 12px rgba(184,160,232,0.4)" : "none",
                        outline: "none",
                      }}
                      aria-label={`Avatar ${av.seed}`}
                    >
                      <img
                        src={avatarUrl(av, 56)}
                        alt={av.seed}
                        width={56} height={56}
                        style={{ borderRadius: "50%", display: "block", width: "100%" }}
                      />
                    </button>
                  );
                })}
              </div>
            </div>

            {error && (
              <p style={{
                fontSize: 13, color: "var(--danger)",
                background: "rgba(232,128,128,0.08)",
                border: "1px solid rgba(232,128,128,0.2)",
                borderRadius: "var(--r-md)", padding: "10px 14px",
              }}>{error}</p>
            )}

            <button
              type="submit"
              disabled={loading || !dob}
              className="btn btn-accent btn-lg"
              style={{
                borderRadius: "var(--r-md)",
                opacity: loading || !dob ? 0.5 : 1,
              }}
            >
              {loading ? "Setting up…" : "Continue →"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

