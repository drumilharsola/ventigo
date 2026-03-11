"use client";

import { Suspense, useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { api } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";
import { AVATARS, avatarUrl } from "@/lib/avatars";
import { FlowLogo } from "@/components/FlowLogo";

const ALL_AVATARS = [...AVATARS];

function fmtDate(ts: string): string {
  if (!ts) return "";
  return new Date(Number(ts) * 1000).toLocaleDateString([], { year: "numeric", month: "long" });
}

function ProfileContent() {
  const router = useRouter();
  const { token, username, avatarId: storeAvatarId, setProfile, _hasHydrated } = useAuthStore();

  // ── Setup mode state ──
  const [dob, setDob] = useState("");
  const [setupAvatarId, setSetupAvatarId] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  // ── View / edit mode state ──
  const [stats, setStats] = useState<{ speak_count: number; listen_count: number; member_since: string } | null>(null);
  const [editing, setEditing] = useState(false);
  const [editAvatarId, setEditAvatarId] = useState(storeAvatarId ?? 0);
  const [rerollName, setRerollName] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (!_hasHydrated) return;
    if (!token) router.push("/verify");
  }, [_hasHydrated, token, router]);

  // Load stats when in view mode
  useEffect(() => {
    if (!token || !username) return;
    api.getMe(token).then((d) => setStats(d)).catch(() => {});
  }, [token, username]);

  const maxDob = (() => {
    const d = new Date();
    d.setFullYear(d.getFullYear() - 18);
    return d.toISOString().split("T")[0];
  })();

  // ── Handlers ──
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (!dob) return;
    setLoading(true);
    try {
      const result = await api.setProfile(token!, { dob, avatar_id: setupAvatarId });
      setProfile(result.username, result.avatar_id);
      router.push("/lobby");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to save profile");
    } finally {
      setLoading(false);
    }
  };

  const handleSaveEdit = async () => {
    setSaving(true);
    setSaveError("");
    try {
      const result = await api.updateProfile(token!, { avatar_id: editAvatarId, reroll_username: rerollName });
      setProfile(result.username, result.avatar_id);
      setEditing(false);
      setRerollName(false);
    } catch (err: unknown) {
      setSaveError(err instanceof Error ? err.message : "Failed to save changes");
    } finally {
      setSaving(false);
    }
  };

  const handleExportData = useCallback(async () => {
    if (!token) return;
    setExporting(true);
    try {
      const data = await api.exportData(token);
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "my-data.json";
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      /* ignore */
    } finally {
      setExporting(false);
    }
  }, [token]);

  const handleDeleteAccount = useCallback(async () => {
    if (!token) return;
    setDeleting(true);
    try {
      await api.deleteAccount(token);
      useAuthStore.getState().clear();
      router.push("/");
    } catch {
      setDeleting(false);
    }
  }, [token, router]);

  // ══════════════════════════════════════════════════
  // VIEW MODE — profile already set up
  // ══════════════════════════════════════════════════
  // Wait for store to rehydrate before deciding which mode to render, so there
  // is no flash of the setup form for users who already have a profile.
  if (!_hasHydrated) {
    return <div style={{ minHeight: "100vh", background: "var(--ink)" }} />;
  }

  if (username) {
    const displayAvatarId = editing ? editAvatarId : (storeAvatarId ?? 0);
    const displayAvatar = ALL_AVATARS.find((a) => a.id === displayAvatarId) ?? ALL_AVATARS[0];
    const total = (stats?.speak_count ?? 0) + (stats?.listen_count ?? 0);

    return (
      <div className="grain" style={{ minHeight: "100vh", background: "var(--ink)", display: "flex" }}>
        <div className="profile-shell" style={{
          display: "grid", gridTemplateColumns: "1fr 1fr",
          minHeight: "100vh", width: "100%",
          position: "relative", zIndex: 5,
        }}>
          <div className="orb orb-a" style={{ position: "fixed" }} />
          <div className="orb orb-c" style={{ position: "fixed" }} />

          {/* LEFT — avatar + identity */}
          <div className="preview-panel" style={{
            padding: "60px 64px",
            display: "flex", flexDirection: "column",
            justifyContent: "space-between",
            borderRight: "1px solid rgba(255,255,255,0.06)",
            position: "relative", zIndex: 5,
          }}>
            <FlowLogo />
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 20, textAlign: "center" }}>
              <div style={{
                width: 140, height: 140, borderRadius: "50%",
                background: "var(--accent-glow)",
                border: "2px solid rgba(184,160,232,0.3)",
                overflow: "hidden",
                boxShadow: "0 0 48px rgba(184,160,232,0.18)",
                transition: "all 0.3s",
              }}>
                <img
                  src={avatarUrl(displayAvatar, 140)}
                  alt="Your avatar"
                  width={140} height={140}
                  style={{ display: "block", width: "100%", borderRadius: "50%" }}
                />
              </div>
              <div>
                <p style={{
                  fontFamily: "var(--font-display)",
                  fontSize: 26, fontWeight: 700, color: "var(--white)",
                  letterSpacing: "-0.02em",
                }}>{username}</p>
                {stats?.member_since && (
                  <p style={{ fontSize: 12, color: "var(--slate)", marginTop: 8, fontFamily: "var(--font-ui)" }}>
                    Member since {fmtDate(stats.member_since)}
                  </p>
                )}
              </div>
            </div>
            <button
              onClick={() => router.push("/lobby")}
              style={{ background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)", textAlign: "left" }}
            >
              ← Back to lobby
            </button>
          </div>

          {/* RIGHT — stats + edit */}
          <div className="form-panel" style={{
            padding: "60px 64px",
            display: "flex", flexDirection: "column", justifyContent: "center",
            position: "relative", zIndex: 5, overflowY: "auto",
          }}>
            {!editing ? (
              <>
                <h2 style={{
                  fontFamily: "var(--font-display)",
                  fontSize: 36, fontWeight: 700, color: "var(--white)",
                  letterSpacing: "-0.025em", marginBottom: 8, lineHeight: 1.15,
                }}>
                  Your<br /><em style={{ color: "var(--accent)" }}>profile.</em>
                </h2>
                <p style={{ fontSize: 14, fontWeight: 300, color: "var(--slate)", marginBottom: 40, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                  These are your session stats so far.
                </p>

                {/* Stats */}
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 14, marginBottom: 40 }}>
                  {[
                    { label: "Total", value: total, icon: "✦" },
                    { label: "Vent", value: stats?.speak_count ?? 0, icon: "🎤" },
                    { label: "Listen", value: stats?.listen_count ?? 0, icon: "👂" },
                  ].map((stat) => (
                    <div key={stat.label} style={{
                      background: "rgba(255,255,255,0.04)",
                      border: "1px solid rgba(255,255,255,0.08)",
                      borderRadius: "var(--r-lg)",
                      padding: "20px 14px",
                      textAlign: "center",
                    }}>
                      <div style={{ fontSize: 20, marginBottom: 8 }}>{stat.icon}</div>
                      <div style={{ fontSize: 30, fontWeight: 800, color: "var(--white)", lineHeight: 1, fontFamily: "var(--font-ui)" }}>
                        {stats ? stat.value : "–"}
                      </div>
                      <div style={{ fontSize: 11, color: "var(--slate)", marginTop: 6, fontFamily: "var(--font-ui)", letterSpacing: "0.06em", textTransform: "uppercase" }}>
                        {stat.label}
                      </div>
                    </div>
                  ))}
                </div>

                <button
                  onClick={() => { setEditing(true); setEditAvatarId(storeAvatarId ?? 0); }}
                  className="btn btn-ghost btn-md"
                  style={{ alignSelf: "flex-start" }}
                >
                  Edit profile
                </button>

                {/* GDPR & Legal */}
                <div style={{ marginTop: 40, paddingTop: 24, borderTop: "1px solid rgba(255,255,255,0.06)" }}>
                  <div style={{ display: "flex", gap: 12, flexWrap: "wrap", marginBottom: 16 }}>
                    <button
                      onClick={handleExportData}
                      disabled={exporting}
                      className="btn btn-ghost btn-sm"
                      style={{ fontSize: 12, opacity: exporting ? 0.5 : 1 }}
                    >
                      {exporting ? "Exporting…" : "Export my data"}
                    </button>
                    <button
                      onClick={() => setShowDeleteConfirm(true)}
                      className="btn btn-ghost btn-sm"
                      style={{ fontSize: 12, color: "var(--danger)" }}
                    >
                      Delete my account
                    </button>
                  </div>
                  <div style={{ display: "flex", gap: 16, fontSize: 12, fontFamily: "var(--font-ui)" }}>
                    <Link href="/privacy" style={{ color: "var(--slate)", textDecoration: "underline" }}>Privacy Policy</Link>
                    <Link href="/terms" style={{ color: "var(--slate)", textDecoration: "underline" }}>Terms of Service</Link>
                  </div>
                </div>

                {showDeleteConfirm && (
                  <div style={{
                    position: "fixed", inset: 0, background: "rgba(0,0,0,0.7)",
                    display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100,
                  }}>
                    <div style={{
                      background: "var(--ink)", border: "1px solid rgba(255,255,255,0.1)",
                      borderRadius: "var(--r-lg)", padding: 32, maxWidth: 400, width: "90%",
                    }}>
                      <h3 style={{ color: "var(--white)", fontSize: 18, fontWeight: 700, marginBottom: 12 }}>
                        Delete your account?
                      </h3>
                      <p style={{ color: "var(--slate)", fontSize: 14, lineHeight: 1.6, marginBottom: 24 }}>
                        This will permanently delete your profile, chat history, and all associated data. This action cannot be undone.
                      </p>
                      <div style={{ display: "flex", gap: 12, justifyContent: "flex-end" }}>
                        <button
                          onClick={() => setShowDeleteConfirm(false)}
                          className="btn btn-ghost btn-sm"
                        >
                          Cancel
                        </button>
                        <button
                          onClick={handleDeleteAccount}
                          disabled={deleting}
                          style={{
                            padding: "8px 20px", borderRadius: 8, border: "none",
                            background: "var(--danger)", color: "white",
                            fontSize: 13, fontWeight: 600, cursor: "pointer",
                            opacity: deleting ? 0.5 : 1,
                          }}
                        >
                          {deleting ? "Deleting…" : "Yes, delete everything"}
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </>
            ) : (
              <>
                <h2 style={{
                  fontFamily: "var(--font-display)",
                  fontSize: 36, fontWeight: 700, color: "var(--white)",
                  letterSpacing: "-0.025em", marginBottom: 8, lineHeight: 1.15,
                }}>
                  Edit your<br /><em style={{ color: "var(--accent)" }}>profile.</em>
                </h2>
                <p style={{ fontSize: 14, fontWeight: 300, color: "var(--slate)", marginBottom: 32, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                  Change your avatar or roll a new username.
                </p>

                <div style={{ marginBottom: 28 }}>
                  <label style={{
                    display: "block", fontSize: 11, fontWeight: 600,
                    letterSpacing: "0.1em", textTransform: "uppercase",
                    color: "var(--slate)", marginBottom: 14, fontFamily: "var(--font-ui)",
                  }}>Choose avatar</label>
                  <div className="avatar-grid" style={{ display: "grid", gridTemplateColumns: "repeat(8, 1fr)", gap: 10 }}>
                    {ALL_AVATARS.map((av) => {
                      const selected = editAvatarId === av.id;
                      return (
                        <button
                          key={av.id}
                          type="button"
                          onClick={() => setEditAvatarId(av.id)}
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
                          <img src={avatarUrl(av, 44)} alt={av.seed} width={44} height={44} style={{ borderRadius: "50%", display: "block", width: "100%" }} />
                        </button>
                      );
                    })}
                  </div>
                </div>

                <label style={{
                  display: "flex", alignItems: "flex-start", gap: 12,
                  cursor: "pointer", marginBottom: 8,
                  padding: "14px 16px",
                  borderRadius: "var(--r-md)",
                  border: `1px solid ${rerollName ? "rgba(184,160,232,0.4)" : "rgba(255,255,255,0.08)"}`,
                  background: rerollName ? "var(--accent-glow)" : "transparent",
                  transition: "all 0.15s",
                }}>
                  <input
                    type="checkbox"
                    checked={rerollName}
                    onChange={(e) => setRerollName(e.target.checked)}
                    style={{ accentColor: "var(--accent)", marginTop: 2 }}
                  />
                  <div>
                    <p style={{ fontSize: 13, fontWeight: 600, color: "var(--fog)", fontFamily: "var(--font-ui)", margin: 0 }}>
                      Re-roll username
                    </p>
                    <p style={{ fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)", margin: "4px 0 0", fontWeight: 300 }}>
                      You&apos;ll get a new randomly generated name.
                    </p>
                  </div>
                </label>

                {saveError && (
                  <p style={{
                    fontSize: 13, color: "var(--danger)",
                    background: "rgba(232,128,128,0.08)",
                    border: "1px solid rgba(232,128,128,0.2)",
                    borderRadius: "var(--r-md)", padding: "10px 14px", marginTop: 12,
                  }}>{saveError}</p>
                )}

                <div style={{ display: "flex", gap: 12, marginTop: 28 }}>
                  <button
                    onClick={() => { setEditing(false); setRerollName(false); setSaveError(""); }}
                    className="btn btn-ghost btn-md"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleSaveEdit}
                    disabled={saving}
                    className="btn btn-accent btn-md"
                    style={{ opacity: saving ? 0.6 : 1 }}
                  >
                    {saving ? "Saving…" : "Save changes"}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    );
  }

  // ══════════════════════════════════════════════════
  // SETUP MODE — first time (no username yet)
  // ══════════════════════════════════════════════════
  const selectedAvatar = ALL_AVATARS.find((a) => a.id === setupAvatarId) ?? ALL_AVATARS[0];

  return (
    <div className="grain" style={{ minHeight: "100vh", background: "var(--ink)", display: "flex" }}>
      <div className="profile-shell" style={{
        display: "grid", gridTemplateColumns: "1fr 1fr",
        minHeight: "100vh", width: "100%",
        position: "relative", zIndex: 5,
      }}>
        <div className="orb orb-a" style={{ position: "fixed" }} />
        <div className="orb orb-c" style={{ position: "fixed" }} />

        {/* LEFT: Live preview */}
        <div className="preview-panel" style={{
          padding: "60px 64px",
          display: "flex", flexDirection: "column",
          justifyContent: "space-between",
          borderRight: "1px solid rgba(255,255,255,0.06)",
          position: "relative", zIndex: 5,
        }}>
          <FlowLogo />
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 20, textAlign: "center" }}>
            <div style={{
              width: 140, height: 140, borderRadius: "50%",
              background: "var(--accent-glow)",
              border: "2px solid rgba(184,160,232,0.3)",
              overflow: "hidden",
              boxShadow: "0 0 48px rgba(184,160,232,0.18)",
              transition: "all 0.3s",
            }}>
              <img src={avatarUrl(selectedAvatar, 140)} alt="Your avatar" width={140} height={140} style={{ display: "block", width: "100%", borderRadius: "50%" }} />
            </div>
            <div>
              <p style={{ fontFamily: "var(--font-display)", fontSize: 22, fontWeight: 400, fontStyle: "italic", color: "var(--fog)" }}>This is you.</p>
              <p className="t-label" style={{ color: "var(--slate)", marginTop: 6 }}>Your username will be revealed after setup.</p>
              <p style={{ marginTop: 18, fontSize: 14, color: "var(--fog)", lineHeight: 1.7, fontFamily: "var(--font-ui)", maxWidth: 380 }}>
                After this step, you&apos;ll be dropped straight into the lobby.
              </p>
            </div>
          </div>
          <p className="t-label" style={{ color: "var(--graphite)", fontSize: 11 }}>Anonymous by design.</p>
        </div>

        {/* RIGHT: Form */}
        <div className="form-panel" style={{
          padding: "60px 64px",
          display: "flex", flexDirection: "column", justifyContent: "center",
          position: "relative", zIndex: 5, overflowY: "auto",
        }}>
          <div style={{ display: "flex", gap: 6, marginBottom: 48 }}>
            {[0, 1, 2].map((i) => (
              <div key={i} style={{
                height: 2, flex: 1, borderRadius: 2,
                background: i < 2 ? "rgba(184,160,232,0.5)" : i === 2 ? "var(--accent)" : "rgba(255,255,255,0.1)",
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
          <p style={{ fontSize: 14, fontWeight: 300, color: "var(--slate)", marginBottom: 36, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
            Just a few details, then we&apos;ll get you into the lobby.
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
              <input className="flow-input" type="date" value={dob} onChange={(e) => setDob(e.target.value)} max={maxDob} required style={{ colorScheme: "dark" }} />
              <p style={{ marginTop: 10, fontSize: 12, color: "var(--slate)", lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                We ask for this only to enforce the age boundary. It is not shown to other users.
              </p>
            </div>

            <div>
              <label style={{
                display: "block", fontSize: 11, fontWeight: 600,
                letterSpacing: "0.1em", textTransform: "uppercase",
                color: "var(--slate)", marginBottom: 14, fontFamily: "var(--font-ui)",
              }}>Choose your avatar</label>
              <div className="avatar-grid" style={{ display: "grid", gridTemplateColumns: "repeat(8, 1fr)", gap: 10 }}>
                {ALL_AVATARS.map((av) => {
                  const selected = setupAvatarId === av.id;
                  return (
                    <button key={av.id} type="button" onClick={() => setSetupAvatarId(av.id)} style={{
                      padding: 3, borderRadius: "50%",
                      border: `2px solid ${selected ? "var(--accent)" : "transparent"}`,
                      background: selected ? "var(--accent-glow)" : "transparent",
                      cursor: "pointer", transition: "all 0.15s",
                      boxShadow: selected ? "0 0 12px rgba(184,160,232,0.4)" : "none",
                      outline: "none",
                    }} aria-label={`Avatar ${av.seed}`}>
                      <img src={avatarUrl(av, 56)} alt={av.seed} width={56} height={56} style={{ borderRadius: "50%", display: "block", width: "100%" }} />
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

            <button type="submit" disabled={loading || !dob} className="btn btn-accent btn-lg" style={{ borderRadius: "var(--r-md)", opacity: loading || !dob ? 0.5 : 1 }}>
              {loading ? "Setting up…" : "Continue →"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

export default function ProfilePage() {
  return (
    <Suspense fallback={<div style={{ minHeight: "100vh", background: "var(--ink)" }} />}>
      <ProfileContent />
    </Suspense>
  );
}
