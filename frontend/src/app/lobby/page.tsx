"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/store/authStore";
import { api, wsUrl, SpeakerRequest, RoomSummary } from "@/lib/api";
import { AVATARS, avatarUrl } from "@/lib/avatars";
import { FlowLogo } from "@/components/FlowLogo";

// ─── Helpers ────────────────────────────────────────────────────────────────

function AvatarImg({ id, size = 40 }: { id: string | number | undefined; size?: number }) {
  return (
    <img
      src={avatarUrl(id, size * 2)}
      alt=""
      width={size}
      height={size}
      style={{ borderRadius: "50%", objectFit: "cover", flexShrink: 0 }}
    />
  );
}

function timeAgo(postedAt: string | number): string {
  const secs = Math.floor(Date.now() / 1000) - Number(postedAt);
  if (secs < 60) return "just now";
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  return `${Math.floor(secs / 3600)}h ago`;
}

// ─── Vent card ───────────────────────────────────────────────────────────────

function VentCard({ req, onAccept, accepting, emailVerified }: {
  req: SpeakerRequest;
  onAccept: (id: string) => void;
  accepting: boolean;
  emailVerified: boolean | null;
}) {
  return (
    <div className="fade-up" style={{
      background: "var(--white)",
      borderRadius: "var(--r-md)",
      padding: "16px 18px",
      display: "flex", alignItems: "center", gap: 14,
      boxShadow: "0 1px 4px rgba(0,0,0,0.05), 0 2px 16px rgba(0,0,0,0.04)",
      border: "1px solid rgba(0,0,0,0.06)",
    }}>
      <AvatarImg id={req.avatar_id} size={42} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ margin: 0, fontWeight: 600, fontSize: 14, color: "var(--ink)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontFamily: "var(--font-ui)" }}>
          {req.username}
        </p>
        <p style={{ margin: "2px 0 0", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
          needs to be heard · {timeAgo(req.posted_at)}
        </p>
      </div>
      <button
        onClick={() => onAccept(req.request_id)}
        disabled={accepting}
        className="btn btn-sm btn-primary"
        style={{ flexShrink: 0, opacity: accepting ? 0.5 : 1 }}
      >
        {accepting ? "…" : "Show up"}
      </button>
    </div>
  );
}

// ─── Main ────────────────────────────────────────────────────────────────────

export default function LobbyPage() {
  const router = useRouter();
  const { token, username, avatarId, emailVerified, setProfile, setAvatarId, clear } = useAuthStore();

  const [board, setBoard] = useState<SpeakerRequest[]>([]);
  const [accepting, setAccepting] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [activeRoomId, setActiveRoomId] = useState<string | null>(null);
  const [rooms, setRooms] = useState<RoomSummary[]>([]);
  const [showEdit, setShowEdit] = useState(false);
  const [ventLoading, setVentLoading] = useState(false);
  const [resendVerifyLoading, setResendVerifyLoading] = useState(false);
  const [resendVerifyDone, setResendVerifyDone] = useState(false);

  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    if (!token) router.push("/verify");
    else if (!username) router.push("/profile");
  }, [token, username, router]);

  useEffect(() => {
    if (!token) return;
    api.getActiveRoom(token).then((r) => setActiveRoomId(r.room_id)).catch(() => {});
    api.getChatRooms(token).then((r) => setRooms(r.rooms)).catch(() => {});
  }, [token]);

  const connectWs = useCallback(() => {
    if (!token) return;
    const ws = new WebSocket(wsUrl.board(token));
    wsRef.current = ws;

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.event === "error" && msg.detail === "token_invalid") { ws.close(); clear(); router.push("/verify"); return; }
      if (msg.event === "board_state") {
        setBoard(msg.requests ?? []);
        if (msg.my_request_id) {
          ws.close();
          router.push(`/waiting?request_id=${encodeURIComponent(msg.my_request_id)}`);
        }
        return;
      }
      if (msg.event === "new_request") {
        setBoard((prev) => {
          if (prev.some((r) => r.request_id === msg.request_id)) return prev;
          return [...prev, { request_id: msg.request_id, session_id: "", username: msg.username, avatar_id: msg.avatar_id ?? "0", posted_at: msg.posted_at }];
        });
        return;
      }
      if (msg.event === "removed_request") { setBoard((prev) => prev.filter((r) => r.request_id !== msg.request_id)); return; }
      if (msg.event === "matched") { ws.close(); router.push(`/chat?room_id=${encodeURIComponent(msg.room_id)}`); }
    };

    ws.onclose = (ev) => {
      if (ev.code === 4401) { clear(); router.push("/verify"); return; }
      setTimeout(() => { if (document.visibilityState !== "hidden") connectWs(); }, 3000);
    };
  }, [token, router, clear]);

  useEffect(() => {
    if (token && username) connectWs();
    return () => wsRef.current?.close();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, username]);

  const handleVent = async () => {
    if (!token) return;
    setError("");
    setVentLoading(true);
    try {
      const res = await api.postSpeak(token);
      wsRef.current?.close();
      router.push(`/waiting?request_id=${encodeURIComponent(res.request_id)}`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Something went wrong");
      setVentLoading(false);
    }
  };

  const handleAccept = async (requestId: string) => {
    if (!token) return;
    setAccepting(requestId);
    setError("");
    try {
      const res = await api.acceptSpeaker(token, requestId);
      router.push(`/chat?room_id=${encodeURIComponent(res.room_id)}`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Couldn't connect - try someone else");
      setAccepting(null);
    }
  };

  const handleResendVerification = async () => {
    if (!token) return;
    setResendVerifyLoading(true);
    try {
      await api.sendVerification(token);
      setResendVerifyDone(true);
    } catch { /* swallow */ }
    finally { setResendVerifyLoading(false); }
  };

  const handleSignOut = () => {
    wsRef.current?.close();
    clear();
    router.push("/");
  };

  return (
    <>
      <div className="light-canvas grain" style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
        <div className="orb-light-a" />
        <div className="orb-light-b" />

        {/* Nav */}
        <nav style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          padding: "18px 32px",
          background: "rgba(248,247,245,0.8)",
          backdropFilter: "blur(12px)",
          borderBottom: "1px solid rgba(0,0,0,0.06)",
          position: "sticky", top: 0, zIndex: 20,
        }}>
          <FlowLogo dark />

          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <button
              onClick={() => setShowEdit(true)}
              style={{
                display: "flex", alignItems: "center", gap: 8,
                padding: "6px 14px 6px 6px",
                borderRadius: "var(--r-full)",
                background: "var(--white)",
                border: "1.5px solid rgba(0,0,0,0.08)",
                cursor: "pointer", transition: "border-color 0.15s",
              }}
              onMouseOver={(e) => { (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--accent)"; }}
              onMouseOut={(e) => { (e.currentTarget as HTMLButtonElement).style.borderColor = "rgba(0,0,0,0.08)"; }}
            >
              <AvatarImg id={avatarId ?? 0} size={28} />
              <span style={{ fontSize: 13, fontWeight: 500, color: "var(--charcoal)", maxWidth: 120, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontFamily: "var(--font-ui)" }}>
                {username}
              </span>
            </button>
            <button
              onClick={handleSignOut}
              style={{ fontSize: 12, color: "var(--slate)", background: "none", border: "none", cursor: "pointer", fontFamily: "var(--font-ui)", fontWeight: 500 }}
            >
              Sign out
            </button>
          </div>
        </nav>

        <main style={{ flex: 1, maxWidth: 680, width: "100%", margin: "0 auto", padding: "40px 24px 64px", display: "flex", flexDirection: "column", gap: 28, position: "relative", zIndex: 2 }}>

          {/* Page title */}
          <div>
            <h1 className="t-display" style={{ color: "var(--ink)", marginBottom: 4, fontSize: "clamp(32px,5vw,52px)" }}>
              Good to see you,<br /><em style={{ color: "var(--accent)" }}>{username}.</em>
            </h1>
            <p style={{ fontSize: 15, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>
              What do you need today?
            </p>
          </div>

          {/* Error */}
          {error && (
            <div style={{ background: "rgba(232,128,128,0.08)", border: "1px solid rgba(232,128,128,0.2)", borderRadius: "var(--r-md)", padding: "12px 16px", fontSize: 13, color: "var(--danger)", fontFamily: "var(--font-ui)" }}>
              {error}
            </div>
          )}

          {/* Continue session banner */}
          {activeRoomId && (
            <button
              onClick={() => router.push(`/chat?room_id=${encodeURIComponent(activeRoomId)}`)}
              style={{
                width: "100%", padding: "16px 20px", borderRadius: "var(--r-md)",
                border: "none",
                background: "var(--ink)",
                color: "var(--white)", fontWeight: 600, fontSize: 14,
                cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: 10,
                boxShadow: "0 4px 16px rgba(13,13,15,0.15)",
                fontFamily: "var(--font-ui)",
              }}
            >
              <span style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--accent)", display: "inline-block" }} />
              Continue your session →
            </button>
          )}

          {/* Action cards */}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
            <button
              onClick={handleVent}
              disabled={ventLoading}
              style={{
                borderRadius: "var(--r-lg)", padding: "28px 22px",
                background: "var(--ink)",
                border: "none", cursor: ventLoading ? "not-allowed" : "pointer",
                display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 12,
                boxShadow: "0 6px 28px rgba(13,13,15,0.15)",
                transition: "transform 0.15s, box-shadow 0.15s",
                textAlign: "left", opacity: ventLoading ? 0.7 : 1,
              }}
              onMouseOver={(e) => { if (!ventLoading) { (e.currentTarget as HTMLButtonElement).style.transform = "translateY(-3px)"; } }}
              onMouseOut={(e) => { (e.currentTarget as HTMLButtonElement).style.transform = ""; }}
            >
              <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span className="pill-dot" />
                <span className="pill pill-accent" style={{ fontSize: 10 }}>I need to vent</span>
              </span>
              <div>
                <p style={{ margin: 0, fontWeight: 700, fontSize: 18, color: "var(--white)", letterSpacing: "-0.3px", fontFamily: "var(--font-display)" }}>
                  {ventLoading ? "Finding your space…" : "Let it out."}
                </p>
                <p style={{ margin: "6px 0 0", fontSize: 13, color: "rgba(255,255,255,0.5)", lineHeight: 1.4, fontFamily: "var(--font-ui)", fontWeight: 300 }}>
                  Share what&apos;s weighing on you
                </p>
              </div>
            </button>

            <div style={{
              borderRadius: "var(--r-lg)", padding: "28px 22px",
              background: "var(--white)",
              border: "1.5px solid rgba(0,0,0,0.07)",
              display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 12,
              boxShadow: "0 2px 12px rgba(0,0,0,0.04)",
            }}>
              <span className="pill" style={{ fontSize: 10 }}>I want to support</span>
              <div>
                <p style={{ margin: 0, fontWeight: 700, fontSize: 18, color: "var(--ink)", letterSpacing: "-0.3px", fontFamily: "var(--font-display)" }}>
                  Be present.
                </p>
                <p style={{ margin: "6px 0 0", fontSize: 13, color: "var(--slate)", lineHeight: 1.4, fontFamily: "var(--font-ui)", fontWeight: 300 }}>
                  Pick someone below and show up for them
                </p>
              </div>
            </div>
          </div>

          {/* Board section */}
          <div>
            {/* Email verification banner */}
            {!emailVerified && (
              <div style={{
                borderRadius: "var(--r-md)", padding: "14px 18px", marginBottom: 14,
                background: "rgba(184,164,244,0.08)",
                border: "1px solid rgba(184,164,244,0.2)",
                display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12,
              }}>
                <p style={{ margin: 0, fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                  🔒 <strong style={{ color: "var(--charcoal)" }}>Verify your email</strong> to accept the request
                </p>
                <button
                  onClick={handleResendVerification}
                  disabled={resendVerifyLoading || resendVerifyDone}
                  className="btn btn-sm"
                  style={{ flexShrink: 0, opacity: resendVerifyLoading || resendVerifyDone ? 0.6 : 1, background: "var(--ink)", color: "var(--white)", border: "none" }}
                >
                  {resendVerifyDone ? "Sent ✓" : resendVerifyLoading ? "Sending…" : "Resend email"}
                </button>
              </div>
            )}
            <p style={{ margin: "0 0 14px", fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
              {board.length > 0
                ? `${board.length} ${board.length === 1 ? "person" : "people"} need a guide`
                : "no one venting right now"}
            </p>

            {board.length === 0 ? (
              <div style={{
                borderRadius: "var(--r-md)", padding: "48px 24px", textAlign: "center",
                border: "1.5px dashed rgba(0,0,0,0.1)",
                background: "var(--white)",
              }}>
                <p style={{ margin: 0, fontWeight: 600, color: "var(--charcoal)", fontSize: 15, fontFamily: "var(--font-ui)" }}>
                  All quiet right now.
                </p>
                <p style={{ margin: "6px 0 0", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>
                  Be the first to open up ↑
                </p>
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                {board.map((req) => (
                  <VentCard key={req.request_id} req={req} onAccept={handleAccept} accepting={accepting === req.request_id} emailVerified={emailVerified} />
                ))}
              </div>
            )}
          </div>

          {/* Past sessions */}
          {rooms.length > 0 && (
            <div>
              <p style={{ margin: "0 0 14px", fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                past sessions
              </p>
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 10 }}>
                {rooms.map((room) => (
                  <button
                    key={room.room_id}
                    onClick={() => router.push(`/chat?room_id=${encodeURIComponent(room.room_id)}`)}
                    style={{
                      display: "flex", alignItems: "center", gap: 10,
                      padding: "12px 14px",
                      borderRadius: "var(--r-md)",
                      border: room.status === "active" ? "1.5px solid var(--accent)" : "1.5px solid rgba(0,0,0,0.07)",
                      background: room.status === "active" ? "var(--accent-glow)" : "var(--white)",
                      cursor: "pointer", textAlign: "left",
                      boxShadow: "0 1px 4px rgba(0,0,0,0.04)",
                      transition: "transform 0.15s",
                    }}
                    onMouseOver={(e) => { (e.currentTarget as HTMLButtonElement).style.transform = "translateY(-1px)"; }}
                    onMouseOut={(e) => { (e.currentTarget as HTMLButtonElement).style.transform = ""; }}
                  >
                    <AvatarImg id={room.peer_avatar_id} size={32} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ margin: 0, fontSize: 13, fontWeight: 600, color: "var(--ink)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontFamily: "var(--font-ui)" }}>
                        {room.peer_username || "Anonymous"}
                      </p>
                      <p style={{ margin: "2px 0 0", fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                        {room.status === "active" ? "Live now" : new Date(Number(room.started_at) * 1000).toLocaleDateString([], { month: "short", day: "numeric" })}
                      </p>
                    </div>
                    {room.status === "active" && (
                      <span style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--accent)", flexShrink: 0 }} />
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}

        </main>
      </div>

      {/* Edit profile modal */}
      {showEdit && (
        <EditProfileModal
          currentAvatarId={avatarId ?? 0}
          currentUsername={username ?? ""}
          token={token!}
          onClose={() => setShowEdit(false)}
          onSaved={(newUsername, newAvatarId) => {
            setProfile(newUsername, newAvatarId);
            setAvatarId(newAvatarId);
            setShowEdit(false);
          }}
        />
      )}
    </>
  );
}

// ─── Edit profile modal ──────────────────────────────────────────────────────

function EditProfileModal({ currentAvatarId, currentUsername, token, onClose, onSaved }: {
  currentAvatarId: number;
  currentUsername: string;
  token: string;
  onClose: () => void;
  onSaved: (username: string, avatarId: number) => void;
}) {
  const [selectedAvatar, setSelectedAvatar] = useState(currentAvatarId);
  const [saving, setSaving] = useState(false);
  const [rerolling, setRerolling] = useState(false);
  const [previewUsername, setPreviewUsername] = useState(currentUsername);

  const handleReroll = async () => {
    setRerolling(true);
    try {
      const res = await api.updateProfile(token, { reroll_username: true });
      setPreviewUsername(res.username);
    } catch { /* swallow */ }
    finally { setRerolling(false); }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const res = await api.updateProfile(token, { avatar_id: selectedAvatar });
      onSaved(res.username, res.avatar_id);
    } catch { /* swallow */ }
    finally { setSaving(false); }
  };

  return (
    <div
      style={{ position: "fixed", inset: 0, zIndex: 60, display: "flex", alignItems: "center", justifyContent: "center", background: "rgba(13,13,15,0.75)", backdropFilter: "blur(8px)", padding: "1rem" }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="glass-card" style={{ width: "100%", maxWidth: 480, padding: "36px 32px", display: "flex", flexDirection: "column", gap: 24 }}>
        {/* Header */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div>
            <h2 style={{ margin: 0, fontSize: 20, fontWeight: 700, color: "var(--white)", fontFamily: "var(--font-display)", letterSpacing: "-0.02em" }}>Your identity</h2>
            <p style={{ margin: "3px 0 0", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>Anonymous - just how you appear here</p>
          </div>
          <button onClick={onClose} style={{ background: "none", border: "none", fontSize: 22, color: "var(--slate)", cursor: "pointer", lineHeight: 1 }}>×</button>
        </div>

        {/* Username */}
        <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 16px", borderRadius: "var(--r-md)", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}>
          <span style={{ flex: 1, fontSize: 15, fontWeight: 600, color: "var(--accent)", fontFamily: "var(--font-ui)" }}>{previewUsername}</span>
          <button
            onClick={handleReroll}
            disabled={rerolling}
            className="btn btn-sm btn-ghost"
            style={{ opacity: rerolling ? 0.5 : 1 }}
          >
            {rerolling ? "Rolling…" : "New name"}
          </button>
        </div>

        {/* Avatar grid */}
        <div>
          <p style={{ margin: "0 0 12px", fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", color: "var(--slate)", textTransform: "uppercase", fontFamily: "var(--font-ui)" }}>Choose avatar</p>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(8, 1fr)", gap: 8 }}>
            {AVATARS.map((av) => (
              <button
                key={av.id}
                onClick={() => setSelectedAvatar(av.id)}
                style={{
                  border: selectedAvatar === av.id ? "2px solid var(--accent)" : "2px solid transparent",
                  borderRadius: "50%", background: "none", cursor: "pointer", padding: 2,
                  boxShadow: selectedAvatar === av.id ? "0 0 12px rgba(184,160,232,0.4)" : "none",
                  transition: "all 0.15s",
                }}
              >
                <img src={avatarUrl(av.id, 64)} alt={av.seed} width={36} height={36} style={{ borderRadius: "50%", display: "block" }} />
              </button>
            ))}
          </div>
        </div>

        <button
          onClick={handleSave}
          disabled={saving}
          className="btn btn-accent btn-md"
          style={{ width: "100%", opacity: saving ? 0.5 : 1 }}
        >
          {saving ? "Saving…" : "Save changes"}
        </button>
      </div>
    </div>
  );
}
