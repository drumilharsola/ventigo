"use client";

import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthStore } from "@/store/authStore";
import { api, wsUrl, SpeakerRequest, RoomSummary, BlockedUser, AuthError } from "@/lib/api";
import { AVATARS, avatarUrl } from "@/lib/avatars";
import { FlowLogo } from "@/components/FlowLogo";
import { Timer } from "@/components/Timer";import { AvatarImg } from "@/components/AvatarImg";
import { timeAgo, groupRoomsByPeer } from "@/lib/utils";
import { useAuthGuard } from "@/lib/useAuthGuard";

// ─── Helpers ────────────────────────────────────────────────────────────────

function filterOwnRequests(requests: SpeakerRequest[], sessionId: string | null) {
  if (!sessionId) return requests;
  return requests.filter((request) => request.session_id !== sessionId);
}

// ─── Wellbeing tips ──────────────────────────────────────────────────────────

const WELLBEING_TIPS = [
  { emoji: "🧘", tip: "Take 3 slow breaths right now. In through your nose, out through your mouth." },
  { emoji: "💧", tip: "Have you had water today? Dehydration amplifies anxiety." },
  { emoji: "🚶", tip: "Even a 5-minute walk outside can shift your mental state meaningfully." },
  { emoji: "✍️", tip: "Write down one thing that went okay today, however small." },
  { emoji: "📵", tip: "Try putting your phone face-down for the next 20 minutes." },
  { emoji: "🌙", tip: "Sleep is emotional regulation. Protecting your sleep is self-care." },
  { emoji: "🤝", tip: "Asking for help is a form of courage, not weakness." },
];

// ─── Vent card ───────────────────────────────────────────────────────────────

function VentCard({ req, onAccept, accepting, emailVerified }: {
  req: SpeakerRequest;
  onAccept: (id: string) => void;
  accepting: boolean;
  emailVerified: boolean | null;
}) {
  const locked = !emailVerified;

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
        {locked && (
          <p style={{ margin: "6px 0 0", fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
            Verify your email to answer this request.
          </p>
        )}
      </div>
      <button
        onClick={() => onAccept(req.request_id)}
        disabled={accepting || locked}
        className="btn btn-sm btn-primary"
        style={{ flexShrink: 0, opacity: accepting || locked ? 0.5 : 1 }}
        title={locked ? "Verify your email to support someone" : undefined}
      >
        {locked ? "Locked" : accepting ? "…" : "Show up"}
      </button>
    </div>
  );
}

// ─── Main ────────────────────────────────────────────────────────────────────

function LobbyContent() {
  const router = useRouter();
  const params = useSearchParams();
  const waitingRequestId = params.get("request_id");
  const { token, sessionId, username, avatarId, emailVerified, setProfile, clear, _hasHydrated } = useAuthStore();

  const [board, setBoard] = useState<SpeakerRequest[]>([]);
  const [accepting, setAccepting] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [rooms, setRooms] = useState<RoomSummary[]>([]);
  const [showEdit, setShowEdit] = useState(false);
  const [ventLoading, setVentLoading] = useState(false);
  const [refreshingBoard, setRefreshingBoard] = useState(false);
  const [resendVerifyLoading, setResendVerifyLoading] = useState(false);
  const [resendVerifyDone, setResendVerifyDone] = useState(false);
  const [pendingRequestId, setPendingRequestId] = useState<string | null>(waitingRequestId);
  const [pendingRemaining, setPendingRemaining] = useState<number | null>(null);
  const [blockedUsers, setBlockedUsers] = useState<BlockedUser[]>([]);
  const [showBlocked, setShowBlocked] = useState(false);
  const [unblocking, setUnblocking] = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);

  useAuthGuard();

  const syncRooms = useCallback(async () => {
    if (!token) return;
    const res = await api.getChatRooms(token);
    setRooms(res.rooms);
  }, [token]);

  const syncBlocked = useCallback(async () => {
    if (!token) return;
    const res = await api.getBlockedUsers(token);
    setBlockedUsers(res.blocked);
  }, [token]);

  useEffect(() => {
    if (!token) return;
    syncBlocked().catch(() => {});
  }, [token, syncBlocked]);

  useEffect(() => {
    if (!token) return;
    syncRooms().catch(() => {});
  }, [token, syncRooms]);

  const groupedRooms = groupRoomsByPeer(rooms);
  const activeGroupedRooms = groupedRooms.filter(({ latest }) => latest.status === "active");

  const syncBoard = useCallback(async () => {
    if (!token) return;
    const res = await api.getBoard(token);
    setBoard(filterOwnRequests(res.requests ?? [], sessionId));
    setPendingRequestId(res.my_request_id ?? null);
  }, [token, sessionId]);

  const handlePendingTimeout = useCallback(async () => {
    if (!token || !pendingRequestId) return;
    try {
      await api.cancelSpeak(token);
    } catch {
      /* swallow */
    }
    setPendingRequestId(null);
    setPendingRemaining(null);
  }, [token, pendingRequestId]);

  const handleCancelPendingRequest = async () => {
    if (!token) return;
    try {
      await api.cancelSpeak(token);
    } catch {
      /* swallow */
    }
    setPendingRequestId(null);
    setPendingRemaining(null);
    setError("");
  };

  const handleRefreshBoard = async () => {
    if (!token) return;
    setRefreshingBoard(true);
    setError("");
    try {
      await syncBoard();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Couldn't refresh the current requests");
    } finally {
      setRefreshingBoard(false);
    }
  };

  const connectWs = useCallback(() => {
    if (!token) return;
    const ws = new WebSocket(wsUrl.board(token));
    wsRef.current = ws;

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.event === "error" && msg.detail === "token_invalid") { ws.close(); clear(); router.push("/verify"); return; }
      if (msg.event === "board_state") {
        setBoard(filterOwnRequests(msg.requests ?? [], sessionId));
        setPendingRequestId(msg.my_request_id ?? null);
        return;
      }
      if (msg.event === "new_request") {
        if (msg.session_id && msg.session_id === sessionId) return;
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
  }, [token, router, clear, sessionId]);

  useEffect(() => {
    if (token && username) connectWs();
    return () => wsRef.current?.close();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, username]);

  useEffect(() => {
    if (!token) return;
    syncBoard().catch(() => {});
  }, [token, syncBoard]);

  useEffect(() => {
    if (!token) return;

    const intervalId = window.setInterval(() => {
      syncRooms().catch(() => {});
    }, 5000);

    return () => window.clearInterval(intervalId);
  }, [token, syncRooms]);

  useEffect(() => {
    if (!token || !pendingRequestId) {
      setPendingRemaining(null);
      return;
    }

    let cancelled = false;
    api.getSpeakerRequest(token, pendingRequestId)
      .then((request) => {
        if (cancelled) return;
        if (request.status === "matched" && request.room_id) {
          setPendingRequestId(null);
          setPendingRemaining(null);
          router.push(`/chat?room_id=${encodeURIComponent(request.room_id)}`);
          return;
        }
        if (!request.posted_at) {
          setPendingRequestId(null);
          setPendingRemaining(null);
          return;
        }
        const elapsed = Math.max(0, Math.floor(Date.now() / 1000) - Number(request.posted_at));
        const nextRemaining = Math.max(0, 10 * 60 - elapsed);
        setPendingRemaining(nextRemaining);
      })
      .catch(() => {
        if (cancelled) return;
        setPendingRequestId(null);
        setPendingRemaining(null);
      });

    return () => {
      cancelled = true;
    };
  }, [token, pendingRequestId, router]);

  const handleVent = async () => {
    if (!token) return;
    setError("");
    setVentLoading(true);
    try {
      const res = await api.postSpeak(token);
      wsRef.current?.close();
      router.push(`/waiting?request_id=${encodeURIComponent(res.request_id)}`);
    } catch (err: unknown) {
      if (err instanceof AuthError) { clear(); router.push("/verify"); return; }
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
      if (err instanceof AuthError) { clear(); router.push("/verify"); return; }
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

  const handleUnblock = async (peerSessionId: string) => {
    if (!token || unblocking) return;
    setUnblocking(peerSessionId);
    try {
      await api.unblockUser(token, peerSessionId);
      setBlockedUsers((prev) => prev.filter((u) => u.peer_session_id !== peerSessionId));
    } catch (e) {
      if (e instanceof AuthError) { clear(); router.push("/verify"); return; }
    } finally { setUnblocking(null); }
  };

  return (
    <>
      <div className="light-canvas grain lobby-shell" style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
        <div className="orb-light-a" />
        <div className="orb-light-b" />

        {/* Nav */}
        <nav className="top-nav" style={{
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

        <main style={{ flex: 1, maxWidth: 1240, width: "100%", margin: "0 auto", padding: "40px 24px 64px", position: "relative", zIndex: 2 }}>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 28, flexWrap: "wrap" }}>
            <div style={{ flex: "1 1 720px", minWidth: 0, display: "flex", flexDirection: "column", gap: 28 }}>
              {/* Page title */}
              <div>
                <h1 className="t-display" style={{ color: "var(--ink)", marginBottom: 4, fontSize: "clamp(32px,5vw,52px)" }}>
                  Good to see you,<br /><em style={{ color: "var(--accent)" }}>{username}.</em>
                </h1>
              </div>

              {/* Error */}
              {error && (
                <div style={{ background: "rgba(232,128,128,0.08)", border: "1px solid rgba(232,128,128,0.2)", borderRadius: "var(--r-md)", padding: "12px 16px", fontSize: 13, color: "var(--danger)", fontFamily: "var(--font-ui)" }}>
                  {error}
                </div>
              )}

              {/* Continue session banner */}
              {activeGroupedRooms.length === 1 && (
                <button
                  onClick={() => router.push(`/chat?room_id=${encodeURIComponent(activeGroupedRooms[0].latest.room_id)}`)}
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
                  Continue with {activeGroupedRooms[0].latest.peer_username || "Anonymous"} →
                </button>
              )}

              {activeGroupedRooms.length > 1 && (
                <div style={{
                  width: "100%",
                  padding: "18px 20px",
                  borderRadius: "var(--r-lg)",
                  background: "var(--ink)",
                  color: "var(--white)",
                  boxShadow: "0 4px 16px rgba(13,13,15,0.15)",
                  display: "flex",
                  flexDirection: "column",
                  gap: 14,
                }}>
                  <div>
                    <p style={{ margin: 0, fontSize: 11, letterSpacing: "0.1em", textTransform: "uppercase", color: "rgba(255,255,255,0.58)", fontFamily: "var(--font-ui)", fontWeight: 600 }}>
                      live conversations
                    </p>
                    <p style={{ margin: "6px 0 0", fontSize: 16, fontWeight: 600, fontFamily: "var(--font-ui)" }}>
                      You have {activeGroupedRooms.length} active chats.
                    </p>
                  </div>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
                    {activeGroupedRooms.map(({ latest }) => (
                      <button
                        key={latest.room_id}
                        onClick={() => router.push(`/chat?room_id=${encodeURIComponent(latest.room_id)}`)}
                        className="btn btn-ghost"
                        style={{ fontSize: 12, color: "var(--white)", borderColor: "rgba(255,255,255,0.18)" }}
                      >
                        {latest.peer_username || "Anonymous"}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Action cards */}
              <div className="action-grid" style={{ display: "flex", flexDirection: "column", gap: 14 }}>
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
                    outline: "none",
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
                      Open a private room and wait for one good listener to show up.
                    </p>
                    {board.length > 0 && (
                      <span style={{
                        fontSize: 11, color: "rgba(255,255,255,0.5)", fontFamily: "var(--font-ui)",
                        display: "flex", alignItems: "center", gap: 5, marginTop: 8,
                      }}>
                        <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#4ade80", display: "inline-block" }} />
                        {board.length} listener{board.length !== 1 ? "s" : ""} available now
                      </span>
                    )}
                  </div>
                </button>

                <div style={{
                  borderRadius: "var(--r-lg)", padding: "22px 22px 20px",
                  background: "var(--white)",
                  border: "1.5px solid rgba(0,0,0,0.07)",
                  display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 14,
                  boxShadow: "0 2px 12px rgba(0,0,0,0.04)",
                  outline: "none",
                }}>
                  <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12, width: "100%", flexWrap: "wrap" }}>
                    <div>
                      <span className="pill" style={{ fontSize: 10, color: "var(--ink)", background: "rgba(0,0,0,0.06)", border: "1px solid rgba(0,0,0,0.1)" }}>I want to listen</span>
                      <p style={{ margin: "12px 0 0", fontWeight: 700, fontSize: 18, color: "var(--ink)", letterSpacing: "-0.3px", fontFamily: "var(--font-display)" }}>
                        Be present.
                      </p>
                      <p style={{ margin: "6px 0 0", fontSize: 13, color: "var(--slate)", lineHeight: 1.4, fontFamily: "var(--font-ui)", fontWeight: 300 }}>
                        Pick someone below, then enter one calm anonymous conversation.
                      </p>
                    </div>
                    <button
                      onClick={handleRefreshBoard}
                      disabled={refreshingBoard}
                      className="btn btn-sm btn-ghost-dark"
                      style={{ opacity: refreshingBoard ? 0.5 : 1 }}
                    >
                      {refreshingBoard ? "Refreshing..." : "Reload"}
                    </button>
                  </div>
                  <p style={{ margin: 0, fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                    {board.length > 0
                      ? `${board.length} ${board.length === 1 ? "person" : "people"} want to be heard`
                      : "no one venting right now"}
                  </p>
                  {!emailVerified && (
                    <p style={{ margin: 0, fontSize: 12, color: "var(--danger)", fontFamily: "var(--font-ui)" }}>
                      Locked until your email is verified.
                    </p>
                  )}
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
                  🔒 <strong style={{ color: "var(--charcoal)" }}>Verify your email</strong> to answer requests and support someone safely.
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
            {board.length === 0 ? (
              <div style={{
                borderRadius: "var(--r-md)", padding: "32px 20px", textAlign: "center",
                border: "1.5px dashed rgba(0,0,0,0.1)", background: "var(--white)",
              }}>
                <p style={{ margin: "0 0 4px", fontWeight: 600, color: "var(--charcoal)", fontSize: 15, fontFamily: "var(--font-ui)" }}>
                  All quiet right now.
                </p>
                <p style={{ margin: "0 0 16px", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>
                  New requests appear automatically — no need to refresh.
                </p>
                <button
                  onClick={() => router.push("/posts")}
                  className="btn btn-sm"
                  style={{ background: "none", border: "1px solid rgba(0,0,0,0.1)", color: "var(--charcoal)" }}
                >
                  Read the community board instead →
                </button>
              </div>
            ) : (
              <div className="board-list" style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                {board.map((req) => (
                  <VentCard key={req.request_id} req={req} onAccept={handleAccept} accepting={accepting === req.request_id} emailVerified={emailVerified} />
                ))}
              </div>
            )}
              </div>
            </div>

            <aside style={{ flex: "0 1 360px", width: "100%", minWidth: 280, position: "sticky", top: 92, alignSelf: "flex-start", display: "flex", flexDirection: "column", gap: 16 }}>
              <div style={{ background: "rgba(255,255,255,0.8)", border: "1px solid rgba(0,0,0,0.08)", borderRadius: "var(--r-lg)", padding: "20px 18px", backdropFilter: "blur(14px)", boxShadow: "0 6px 20px rgba(0,0,0,0.05)" }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12, marginBottom: 16 }}>
                  <div>
                    <p style={{ margin: "0 0 4px", fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                      chat history
                    </p>
                  </div>
                  {groupedRooms.length > 0 && (
                    <button onClick={() => router.push("/history")} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--slate)", fontSize: 12, fontFamily: "var(--font-ui)", fontWeight: 600 }}>
                      View all
                    </button>
                  )}
                </div>

                {groupedRooms.length === 0 ? (
                  <div style={{ borderRadius: "var(--r-md)", padding: "28px 18px", background: "var(--white)", border: "1px dashed rgba(0,0,0,0.1)", textAlign: "center" }}>
                    <p style={{ margin: 0, fontSize: 14, fontWeight: 600, color: "var(--charcoal)", fontFamily: "var(--font-ui)" }}>
                      No chat history yet.
                    </p>
                    <p style={{ margin: "6px 0 0", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                      Your recent connections will appear here for 7 days.
                    </p>
                  </div>
                ) : (
                  <div className="history-grid" style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                    {groupedRooms.slice(0, 2).map(({ latest, count }) => (
                      <button
                        key={latest.peer_session_id || latest.room_id}
                        onClick={() => router.push(`/chat?room_id=${encodeURIComponent(latest.room_id)}${latest.peer_session_id ? `&peer_session_id=${encodeURIComponent(latest.peer_session_id)}` : ""}`)}
                        style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 14px", borderRadius: "var(--r-md)", border: latest.status === "active" ? "1.5px solid var(--accent)" : "1.5px solid rgba(0,0,0,0.07)", background: latest.status === "active" ? "var(--accent-glow)" : "var(--white)", cursor: "pointer", textAlign: "left", boxShadow: "0 1px 4px rgba(0,0,0,0.04)" }}
                      >
                        <AvatarImg id={latest.peer_avatar_id} size={34} />
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <p style={{ margin: 0, fontSize: 13, fontWeight: 600, color: "var(--ink)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontFamily: "var(--font-ui)" }}>
                            {latest.peer_username || "Anonymous"}
                          </p>
                          <p style={{ margin: "3px 0 0", fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                            {count === 1 ? "1 session" : `${count} sessions`} · {latest.status === "active" ? "Live now" : new Date(Number(latest.started_at || latest.matched_at) * 1000).toLocaleDateString([], { month: "short", day: "numeric" })}
                          </p>
                        </div>
                        {latest.status === "active" && (
                          <span style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--accent)", flexShrink: 0 }} />
                        )}
                      </button>
                    ))}
                    {groupedRooms.length > 2 && (
                      <button
                        onClick={() => router.push("/history")}
                        style={{ fontSize: 12, color: "var(--slate)", background: "none", border: "none", cursor: "pointer", textAlign: "center", padding: "6px 0", fontFamily: "var(--font-ui)", fontWeight: 600 }}
                      >
                        +{groupedRooms.length - 2} more →
                      </button>
                    )}
                  </div>
                )}
              </div>

              {/* Daily wellbeing tip */}
              <div style={{ background: "rgba(184,164,244,0.08)", border: "1px solid rgba(184,164,244,0.15)", borderRadius: "var(--r-lg)", padding: "16px 18px" }}>
                <p style={{ margin: 0, fontSize: 22, lineHeight: 1 }}>{WELLBEING_TIPS[new Date().getDate() % WELLBEING_TIPS.length].emoji}</p>
                <p style={{ margin: "8px 0 0", fontSize: 13, color: "var(--charcoal)", fontFamily: "var(--font-ui)", lineHeight: 1.5, fontWeight: 300 }}>
                  {WELLBEING_TIPS[new Date().getDate() % WELLBEING_TIPS.length].tip}
                </p>
              </div>

              {/* Community board link */}
              <button
                onClick={() => router.push("/posts")}
                style={{
                  width: "100%", padding: "14px 18px", borderRadius: "var(--r-lg)",
                  background: "rgba(255,255,255,0.8)", border: "1px solid rgba(0,0,0,0.08)",
                  cursor: "pointer", textAlign: "left",
                  backdropFilter: "blur(14px)", boxShadow: "0 6px 20px rgba(0,0,0,0.05)",
                }}
              >
                <p style={{ margin: 0, fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                  community board
                </p>
                <p style={{ margin: "4px 0 0", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>
                  Read or share anonymous thoughts →
                </p>
              </button>

              {/* Blocked users panel */}
              {blockedUsers.length > 0 && (
                <div style={{ background: "rgba(255,255,255,0.8)", border: "1px solid rgba(0,0,0,0.08)", borderRadius: "var(--r-lg)", padding: "20px 18px", backdropFilter: "blur(14px)", boxShadow: "0 6px 20px rgba(0,0,0,0.05)" }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
                    <p style={{ margin: 0, fontSize: 11, fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "var(--danger)", fontFamily: "var(--font-ui)", opacity: 0.7 }}>
                      Blocked · {blockedUsers.length}
                    </p>
                    <div style={{ display: "flex", gap: 10 }}>
                      {blockedUsers.length > 2 && (
                        <button onClick={() => router.push("/history?tab=blocked")} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--slate)", fontSize: 12, fontFamily: "var(--font-ui)", fontWeight: 600 }}>
                          View all
                        </button>
                      )}
                      <button
                        onClick={() => setShowBlocked((v) => !v)}
                        style={{ background: "none", border: "none", cursor: "pointer", color: "var(--slate)", fontSize: 12, fontFamily: "var(--font-ui)" }}
                      >
                        {showBlocked ? "Hide" : "Manage"}
                      </button>
                    </div>
                  </div>
                  {showBlocked && (
                    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                      {blockedUsers.slice(0, 2).map((u) => (
                        <div key={u.peer_session_id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 12px", borderRadius: "var(--r-md)", background: "var(--white)", border: "1px solid rgba(0,0,0,0.06)" }}>
                          <AvatarImg id={u.avatar_id} size={32} />
                          <p style={{ flex: 1, margin: 0, fontSize: 13, fontWeight: 600, color: "var(--ink)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontFamily: "var(--font-ui)" }}>
                            {u.username || "Unknown"}
                          </p>
                          <button
                            onClick={() => handleUnblock(u.peer_session_id)}
                            disabled={unblocking === u.peer_session_id}
                            className="btn btn-sm"
                            style={{ flexShrink: 0, fontSize: 11, background: "none", border: "1px solid rgba(0,0,0,0.12)", color: "var(--slate)", opacity: unblocking === u.peer_session_id ? 0.5 : 1 }}
                          >
                            {unblocking === u.peer_session_id ? "…" : "Unblock"}
                          </button>
                        </div>
                      ))}
                      {blockedUsers.length > 2 && (
                        <button
                          onClick={() => router.push("/history?tab=blocked")}
                          style={{ fontSize: 12, color: "var(--slate)", background: "none", border: "none", cursor: "pointer", textAlign: "center", padding: "6px 0", fontFamily: "var(--font-ui)", fontWeight: 600 }}
                        >
                          +{blockedUsers.length - 2} more →
                        </button>
                      )}
                    </div>
                  )}
                </div>
              )}
            </aside>
          </div>
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
            setShowEdit(false);
          }}
        />
      )}

      {pendingRequestId && pendingRemaining !== null && pendingRemaining > 0 && (
        <div style={{
          position: "fixed",
          right: 24,
          bottom: 24,
          width: "min(360px, calc(100vw - 32px))",
          padding: "18px 18px 16px",
          borderRadius: "var(--r-lg)",
          background: "rgba(13,13,15,0.92)",
          border: "1px solid rgba(255,255,255,0.08)",
          backdropFilter: "blur(18px)",
          boxShadow: "0 18px 40px rgba(0,0,0,0.28)",
          zIndex: 30,
        }}>
          <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12, marginBottom: 14 }}>
            <div>
              <p style={{ margin: 0, fontSize: 13, fontWeight: 600, color: "var(--white)", fontFamily: "var(--font-ui)" }}>
                Waiting for someone to join
              </p>
              <p style={{ margin: "4px 0 0", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                Most connections happen within the first few minutes.
              </p>
            </div>
            <button onClick={() => router.push(`/waiting?request_id=${encodeURIComponent(pendingRequestId!)}`)} className="btn btn-sm btn-ghost">
              Expand
            </button>
          </div>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
            <Timer remainingSeconds={pendingRemaining} onEnd={() => { void handlePendingTimeout(); }} />
            <button onClick={handleCancelPendingRequest} className="btn btn-sm btn-ghost">
              Cancel
            </button>
          </div>
        </div>
      )}
    </>
  );
}

export default function LobbyPage() {
  return (
    <Suspense fallback={<div style={{ minHeight: "100vh", background: "var(--snow)" }} />}>
      <LobbyContent />
    </Suspense>
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
  const [stats, setStats] = useState<{ speak_count: number; listen_count: number } | null>(null);

  useEffect(() => {
    api.getMe(token).then((d) => setStats(d)).catch(() => {});
  }, [token]);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

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

        {/* Stats */}
        <div style={{
          background: "rgba(255,255,255,0.05)",
          border: "1px solid rgba(255,255,255,0.08)",
          borderRadius: "var(--r-md)",
          padding: "18px 20px",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 12,
        }}>
          <div style={{ textAlign: "center" }}>
            <div style={{ fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: 6 }}>Total sessions</div>
            <div style={{ fontSize: 48, fontWeight: 800, color: "var(--white)", lineHeight: 1, fontFamily: "var(--font-ui)" }}>
              {stats ? (stats.speak_count + stats.listen_count) : "–"}
            </div>
          </div>
          <div style={{ display: "flex", gap: 20, borderTop: "1px solid rgba(255,255,255,0.07)", paddingTop: 12, width: "100%", justifyContent: "center" }}>
            <div style={{ textAlign: "center" }}>
              <div style={{ fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)", marginBottom: 3 }}>🎤 Vent</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: "var(--white)", lineHeight: 1, fontFamily: "var(--font-ui)" }}>
                {stats ? stats.speak_count : "–"}
              </div>
            </div>
            <div style={{ width: 1, background: "rgba(255,255,255,0.07)" }} />
            <div style={{ textAlign: "center" }}>
              <div style={{ fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)", marginBottom: 3 }}>👂 Listen</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: "var(--white)", lineHeight: 1, fontFamily: "var(--font-ui)" }}>
                {stats ? stats.listen_count : "–"}
              </div>
            </div>
          </div>
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
