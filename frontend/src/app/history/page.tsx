"use client";

import { useEffect, useState, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthStore } from "@/store/authStore";
import { api, RoomSummary, BlockedUser, ConnectionItem } from "@/lib/api";
import { avatarUrl } from "@/lib/avatars";
import { FlowLogo } from "@/components/FlowLogo";
import { AvatarImg } from "@/components/AvatarImg";
import { groupRoomsByPeer } from "@/lib/utils";
import { useAuthGuard } from "@/lib/useAuthGuard";

function formatDate(unixStr: string): string {
  if (!unixStr) return "";
  const d = new Date(Number(unixStr) * 1000);
  return d.toLocaleDateString([], { month: "short", day: "numeric", year: "numeric" }) +
    " · " +
    d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function formatDuration(startedAt: string, endedAt: string): string {
  if (!startedAt || !endedAt) return "15 min window";
  const diffMinutes = Math.max(1, Math.round((Number(endedAt) - Number(startedAt)) / 60));
  return `${diffMinutes} min`;
}

function roomSortTs(room: Pick<RoomSummary, "started_at" | "matched_at">): number {
  return Number(room.started_at || room.matched_at || 0);
}

function formatTotalDuration(rooms: RoomSummary[], peerSessionId: string): string {
  let totalMinutes = 0;
  for (const room of rooms) {
    if (room.peer_session_id !== peerSessionId) continue;
    if (room.started_at && room.ended_at) {
      totalMinutes += Math.max(1, Math.round((Number(room.ended_at) - Number(room.started_at)) / 60));
    }
  }
  return totalMinutes > 0 ? `${totalMinutes} min` : "";
}

function HistoryContent() {
  const router = useRouter();
  const params = useSearchParams();
  const initialTab = (params.get("tab") === "blocked" ? "blocked" : params.get("tab") === "connections" ? "connections" : "chat") as "chat" | "connections" | "blocked";
  const { token, username, _hasHydrated } = useAuthStore();
  const [tab, setTab] = useState<"chat" | "connections" | "blocked">(initialTab);
  const [rooms, setRooms] = useState<RoomSummary[]>([]);
  const [blockedUsers, setBlockedUsers] = useState<BlockedUser[]>([]);
  const [connections, setConnections] = useState<ConnectionItem[]>([]);
  const [pendingRequests, setPendingRequests] = useState<ConnectionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [unblocking, setUnblocking] = useState<string | null>(null);

  useAuthGuard();

  useEffect(() => {
    if (!_hasHydrated || !token || !username) return;
    Promise.all([
      api.getChatRooms(token).then((res) => setRooms(res.rooms)),
      api.getBlockedUsers(token).then((res) => setBlockedUsers(res.blocked)),
      api.getConnections(token).then((res) => { setConnections(res.connections); setPendingRequests(res.pending_requests); }),
    ]).catch(() => {}).finally(() => setLoading(false));
  }, [_hasHydrated, token, username, router]);

  const handleUnblock = async (peerSessionId: string) => {
    if (!token || unblocking) return;
    setUnblocking(peerSessionId);
    try {
      await api.unblockUser(token, peerSessionId);
      setBlockedUsers((prev) => prev.filter((u) => u.peer_session_id !== peerSessionId));
    } catch { /* swallow */ } finally { setUnblocking(null); }
  };

  const groupedRooms = groupRoomsByPeer(rooms);

  const tabStyle = (active: boolean): React.CSSProperties => ({
    padding: "8px 20px", borderRadius: "var(--r-full)",
    border: "none", cursor: "pointer", fontFamily: "var(--font-ui)",
    fontSize: 13, fontWeight: 600, transition: "all 0.15s",
    background: active ? "var(--ink)" : "transparent",
    color: active ? "var(--white)" : "var(--slate)",
  });

  return (
    <div className="light-canvas grain history-shell" style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
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
        <button
          onClick={() => router.push("/lobby")}
          style={{ fontSize: 13, color: "var(--slate)", background: "none", border: "none", cursor: "pointer", fontFamily: "var(--font-ui)", fontWeight: 500 }}
        >
          ← Lobby
        </button>
      </nav>

      <main style={{ flex: 1, maxWidth: 720, width: "100%", margin: "0 auto", padding: "56px 24px 80px", position: "relative", zIndex: 2 }}>
        {/* Header */}
        <div style={{ marginBottom: 36 }}>
          <h1 className="t-display" style={{ color: "var(--ink)", fontSize: "clamp(36px,6vw,64px)" }}>
            {tab === "chat" && <>Your <em style={{ color: "var(--accent)" }}>conversations.</em></>}
            {tab === "connections" && <>Your <em style={{ color: "var(--accent)" }}>connections.</em></>}
            {tab === "blocked" && <>Blocked <em style={{ color: "var(--danger)" }}>users.</em></>}
          </h1>
          <p style={{ fontSize: 14, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300, marginTop: 8 }}>
            {tab === "chat" && "Every session, preserved in quiet."}
            {tab === "connections" && "People you've connected with for direct conversations."}
            {tab === "blocked" && "People you've blocked won't appear in your conversations or board."}
          </p>
        </div>

        {/* Tabs */}
        <div style={{ display: "flex", gap: 6, marginBottom: 40, background: "rgba(0,0,0,0.04)", borderRadius: "var(--r-full)", padding: 4, width: "fit-content" }}>
          <button style={tabStyle(tab === "chat")} onClick={() => setTab("chat")}>
            Conversations {groupedRooms.length > 0 ? `· ${groupedRooms.length}` : ""}
          </button>
          <button style={tabStyle(tab === "connections")} onClick={() => setTab("connections")}>
            Connections {connections.length + pendingRequests.length > 0 ? `· ${connections.length + pendingRequests.length}` : ""}
          </button>
          <button style={tabStyle(tab === "blocked")} onClick={() => setTab("blocked")}>
            Blocked {blockedUsers.length > 0 ? `· ${blockedUsers.length}` : ""}
          </button>
        </div>

        {/* Loading */}
        {loading && (
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", padding: "80px 0" }}>
            <div style={{ width: 28, height: 28, borderRadius: "50%", border: "2px solid rgba(184,160,232,0.2)", borderTopColor: "var(--accent)", animation: "logo-spin 0.8s linear infinite" }} />
          </div>
        )}

        {/* ── Chat tab ── */}
        {!loading && tab === "chat" && (
          <>
            {groupedRooms.length === 0 ? (
              <div style={{ borderRadius: "var(--r-lg)", padding: "60px 32px", textAlign: "center", border: "1.5px dashed rgba(0,0,0,0.1)", background: "var(--white)" }}>
                <p style={{ margin: 0, fontWeight: 600, color: "var(--charcoal)", fontSize: 16, fontFamily: "var(--font-ui)" }}>No conversations yet.</p>
                <p style={{ margin: "8px 0 24px", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>Your sessions will appear here after you connect with someone.</p>
                <button onClick={() => router.push("/lobby")} className="btn btn-primary btn-md">Go to lobby</button>
              </div>
            ) : (
              <>
              <p style={{ margin: "0 0 20px", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>
                Your recent connections will appear here for 7 days.
              </p>
              <div className="conversation-list" style={{ display: "flex", flexDirection: "column" }}>
                {groupedRooms.map(({ latest, count }, i) => (
                  <button
                    key={latest.peer_session_id || latest.room_id}
                    onClick={() => router.push(`/chat?room_id=${encodeURIComponent(latest.room_id)}${latest.peer_session_id ? `&peer_session_id=${encodeURIComponent(latest.peer_session_id)}` : ""}`)}
                    style={{
                      display: "flex", alignItems: "center", gap: 20, padding: "22px 0",
                      background: "none", border: "none",
                      borderBottom: i < groupedRooms.length - 1 ? "1px solid rgba(0,0,0,0.07)" : "none",
                      cursor: "pointer", textAlign: "left", width: "100%", transition: "opacity 0.15s",
                    }}
                    onMouseOver={(e) => { (e.currentTarget as HTMLButtonElement).style.opacity = "0.7"; }}
                    onMouseOut={(e) => { (e.currentTarget as HTMLButtonElement).style.opacity = "1"; }}
                  >
                    <span style={{ fontSize: 11, fontWeight: 600, color: "var(--mist)", fontFamily: "var(--font-ui)", letterSpacing: "0.05em", minWidth: 28, flexShrink: 0 }}>
                      {String(i + 1).padStart(2, "0")}
                    </span>
                    <img src={avatarUrl(latest.peer_avatar_id, 72)} alt="avatar" width={44} height={44} style={{ borderRadius: "50%", flexShrink: 0, border: "2px solid rgba(0,0,0,0.06)" }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ margin: 0, fontWeight: 600, fontSize: 15, fontFamily: "var(--font-ui)", color: "var(--ink)", fontStyle: "italic", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {latest.peer_username || "Anonymous"}
                      </p>
                      <p style={{ margin: "3px 0 0", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                        {count === 1 ? formatDate(latest.started_at || latest.matched_at) : `${count} sessions · ${formatTotalDuration(rooms, latest.peer_session_id)} total`}
                      </p>
                    </div>
                    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 6, flexShrink: 0 }}>
                      {latest.status === "active" ? (
                        <span className="pill pill-success" style={{ flexShrink: 0, gap: 6 }}>
                          <span className="pill-dot" style={{ background: "var(--success)", animation: "pulse-dot 2s ease-in-out infinite" }} />
                          Live
                        </span>
                      ) : (
                        <span style={{ fontSize: 12, color: "var(--mist)", fontFamily: "var(--font-ui)", flexShrink: 0 }}>Ended</span>
                      )}
                      <span style={{ fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                        {latest.status === "active" ? "Open now" : formatDuration(latest.started_at || latest.matched_at, latest.ended_at)}
                      </span>
                    </div>
                  </button>
                ))}
              </div>
              </>
            )}
          </>
        )}

        {/* ── Connections tab ── */}
        {!loading && tab === "connections" && (
          <>
            {pendingRequests.length > 0 && (
              <>
                <p style={{ margin: "0 0 16px", fontSize: 13, fontWeight: 600, color: "var(--accent)", fontFamily: "var(--font-ui)" }}>Pending requests</p>
                <div style={{ display: "flex", flexDirection: "column", marginBottom: 32 }}>
                  {pendingRequests.map((req, i) => (
                    <div key={req.id} style={{ display: "flex", alignItems: "center", gap: 16, padding: "14px 0", borderBottom: i < pendingRequests.length - 1 ? "1px solid rgba(0,0,0,0.07)" : "none" }}>
                      <img src={avatarUrl(req.peer_avatar_id, 72)} alt="avatar" width={40} height={40} style={{ borderRadius: "50%", border: "2px solid rgba(184,160,232,0.3)" }} />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <p style={{ margin: 0, fontWeight: 600, fontSize: 14, fontFamily: "var(--font-ui)", color: "var(--ink)", fontStyle: "italic" }}>{req.peer_username || "Anonymous"}</p>
                        <p style={{ margin: "2px 0 0", fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>Wants to connect</p>
                      </div>
                      <button
                        onClick={() => {
                          if (!token) return;
                          api.acceptConnectionRequest(token, req.peer_session_id).then(() => {
                            setPendingRequests((prev) => prev.filter((r) => r.id !== req.id));
                            setConnections((prev) => [...prev, { ...req, status: "accepted" }]);
                          }).catch(() => {});
                        }}
                        className="btn btn-sm btn-accent"
                      >Accept</button>
                    </div>
                  ))}
                </div>
              </>
            )}
            {connections.length === 0 && pendingRequests.length === 0 ? (
              <div style={{ borderRadius: "var(--r-lg)", padding: "60px 32px", textAlign: "center", border: "1.5px dashed rgba(0,0,0,0.1)", background: "var(--white)" }}>
                <p style={{ margin: 0, fontWeight: 600, color: "var(--charcoal)", fontSize: 16, fontFamily: "var(--font-ui)" }}>No connections yet.</p>
                <p style={{ margin: "8px 0 0", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>After a good chat, tap &ldquo;Connect&rdquo; to save that person.</p>
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column" }}>
                {connections.map((conn, i) => (
                  <div key={conn.id} style={{ display: "flex", alignItems: "center", gap: 16, padding: "18px 0", borderBottom: i < connections.length - 1 ? "1px solid rgba(0,0,0,0.07)" : "none" }}>
                    <img src={avatarUrl(conn.peer_avatar_id, 72)} alt="avatar" width={44} height={44} style={{ borderRadius: "50%", border: "2px solid rgba(184,160,232,0.3)" }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ margin: 0, fontWeight: 600, fontSize: 15, fontFamily: "var(--font-ui)", color: "var(--ink)", fontStyle: "italic" }}>{conn.peer_username || "Anonymous"}</p>
                    </div>
                    <button
                      onClick={() => {
                        if (!token) return;
                        api.directChat(token, conn.peer_session_id).then((res) => {
                          router.push(`/chat?room_id=${encodeURIComponent(res.room_id)}`);
                        }).catch(() => {});
                      }}
                      className="btn btn-sm btn-accent"
                    >Start chat</button>
                    <button
                      onClick={() => {
                        if (!token) return;
                        api.removeConnection(token, conn.peer_session_id).then(() => {
                          setConnections((prev) => prev.filter((c) => c.id !== conn.id));
                        }).catch(() => {});
                      }}
                      className="btn btn-sm btn-ghost"
                      style={{ color: "var(--danger)", fontSize: 11 }}
                    >Remove</button>
                  </div>
                ))}
              </div>
            )}
          </>
        )}

        {/* ── Blocked tab ── */}
        {!loading && tab === "blocked" && (
          <>
            {blockedUsers.length === 0 ? (
              <div style={{ borderRadius: "var(--r-lg)", padding: "60px 32px", textAlign: "center", border: "1.5px dashed rgba(0,0,0,0.1)", background: "var(--white)" }}>
                <p style={{ margin: 0, fontWeight: 600, color: "var(--charcoal)", fontSize: 16, fontFamily: "var(--font-ui)" }}>No blocked users.</p>
                <p style={{ margin: "8px 0 0", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>People you block appear here.</p>
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column" }}>
                {blockedUsers.map((u, i) => (
                  <div
                    key={u.peer_session_id}
                    style={{
                      display: "flex", alignItems: "center", gap: 20, padding: "18px 0",
                      borderBottom: i < blockedUsers.length - 1 ? "1px solid rgba(0,0,0,0.07)" : "none",
                    }}
                  >
                    <span style={{ fontSize: 11, fontWeight: 600, color: "var(--mist)", fontFamily: "var(--font-ui)", letterSpacing: "0.05em", minWidth: 28, flexShrink: 0 }}>
                      {String(i + 1).padStart(2, "0")}
                    </span>
                    <img src={avatarUrl(u.avatar_id, 72)} alt="avatar" width={44} height={44} style={{ borderRadius: "50%", flexShrink: 0, border: "2px solid rgba(232,128,128,0.2)" }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ margin: 0, fontWeight: 600, fontSize: 15, fontFamily: "var(--font-ui)", color: "var(--ink)", fontStyle: "italic", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {u.username || "Unknown"}
                      </p>
                      <p style={{ margin: "3px 0 0", fontSize: 12, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                        Blocked {u.blocked_at ? formatDate(u.blocked_at) : ""}
                      </p>
                    </div>
                    <button
                      onClick={() => handleUnblock(u.peer_session_id)}
                      disabled={unblocking === u.peer_session_id}
                      className="btn btn-sm"
                      style={{ flexShrink: 0, fontSize: 12, background: "none", border: "1px solid rgba(0,0,0,0.12)", color: "var(--slate)", opacity: unblocking === u.peer_session_id ? 0.5 : 1 }}
                    >
                      {unblocking === u.peer_session_id ? "…" : "Unblock"}
                    </button>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </main>
    </div>
  );
}

export default function HistoryPage() {
  return (
    <Suspense fallback={
      <div style={{ height: "100vh", display: "flex", alignItems: "center", justifyContent: "center", background: "var(--white)" }}>
        <div style={{ width: 28, height: 28, borderRadius: "50%", border: "2px solid rgba(184,160,232,0.2)", borderTopColor: "var(--accent)", animation: "logo-spin 0.8s linear infinite" }} />
      </div>
    }>
      <HistoryContent />
    </Suspense>
  );
}
