"use client";

import { useEffect, useRef, useState, useCallback, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthStore } from "@/store/authStore";
import { api, wsUrl } from "@/lib/api";
import { Timer } from "@/components/Timer";
import { TypingIndicator } from "@/components/TypingIndicator";
import { SessionEndModal } from "@/components/SessionEndModal";
import { ReportModal } from "@/components/ReportModal";
import { UserProfileModal } from "@/components/UserProfileModal";
import { avatarUrl } from "@/lib/avatars";
import { FlowLogo } from "@/components/FlowLogo";

interface ChatMessage {
  type: "message";
  from: string;
  text: string;
  ts: number;
  client_id?: string;
}

interface SessionMarker {
  type: "session_marker";
  event: "started" | "ended";
  roomId: string;
  ts: number;
}

type TranscriptItem = ChatMessage | SessionMarker;

type WsEvent =
  | (ChatMessage & { room_id?: string })
  | { type: "history"; messages: ChatMessage[] }
  | { type: "typing_start"; from: string; room_id?: string }
  | { type: "typing_stop"; from: string; room_id?: string }
  | { type: "timer_status"; started: boolean; remaining: number; room_id?: string }
  | { type: "tick"; remaining: number; room_id?: string }
  | { type: "session_end"; room_id?: string }
  | { type: "peer_left"; room_id?: string }
  | { type: "extended"; remaining: number; room_id?: string }
  | { type: "error"; detail: string };

function ChatContent() {
  const router = useRouter();
  const params = useSearchParams();
  const roomId = params.get("room_id") ?? "";
  const peerSessionId = params.get("peer_session_id") ?? "";

  const { token, username, _hasHydrated } = useAuthStore();

  const [messages, setMessages] = useState<TranscriptItem[]>([]);
  const [input, setInput] = useState("");
  const [remaining, setRemaining] = useState(15 * 60);
  const [timerStarted, setTimerStarted] = useState(false);
  const appendSessionMarkerRef = useRef<(event: "started" | "ended", ts?: number) => void>(() => {});
  const [roomStartedMarkerTs, setRoomStartedMarkerTs] = useState<number | null>(null);
  const [peerUsername, setPeerUsername] = useState<string | null>(null);
  const [peerAvatarId, setPeerAvatarId] = useState<number>(0);
  const [resolvedPeerSessionId, setResolvedPeerSessionId] = useState<string>(peerSessionId);
  const [peerTyping, setPeerTyping] = useState(false);
  const [sessionEnded, setSessionEnded] = useState(false);
  const [peerLeft, setPeerLeft] = useState(false);
  const [canExtend, setCanExtend] = useState(true);
  const [showReport, setShowReport] = useState(false);
  const [blocking, setBlocking] = useState(false);
  const [blocked, setBlocked] = useState(false);
  const [confirmingBlock, setConfirmingBlock] = useState(false);
  const [connected, setConnected] = useState(false);
  const [connectionError, setConnectionError] = useState("");
  const [mode, setMode] = useState<"checking" | "live" | "readonly" | "expired">("checking");
  const [showPeerProfile, setShowPeerProfile] = useState(false);

  const wsRef = useRef<WebSocket | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const typingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isTypingRef = useRef(false);
  const timerStartedRef = useRef(false);
  const messagesContainerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => { timerStartedRef.current = timerStarted; }, [timerStarted]);

  // ESC navigates back to lobby (same as waiting page minimize)
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") router.push("/lobby"); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [router]);

  const getRoomSortTs = (room: { started_at: string; matched_at: string }) => Number(room.started_at || room.matched_at || 0);

  const mergeTranscriptItems = useCallback((existing: TranscriptItem[], incoming: TranscriptItem[]) => {
    const merged = [...existing];

    for (const item of incoming) {
      if (item.type === "session_marker") {
        const exists = merged.some(
          (entry) =>
            entry.type === "session_marker" &&
            entry.roomId === item.roomId &&
            entry.event === item.event &&
            entry.ts === item.ts,
        );
        if (!exists) merged.push(item);
        continue;
      }

      const exists = merged.some(
        (entry) =>
          entry.type === "message" &&
          ((entry.client_id && item.client_id && entry.client_id === item.client_id) ||
            (entry.from === item.from && entry.text === item.text && entry.ts === item.ts)),
      );
      if (!exists) merged.push(item);
    }

    return merged.sort((a, b) => a.ts - b.ts);
  }, []);

  const appendSessionMarker = useCallback((event: "started" | "ended", ts?: number) => {
    if (!roomId) return;
    const markerTs = ts ?? (event === "started" ? roomStartedMarkerTs : null) ?? Math.floor(Date.now() / 1000);
    setMessages((prev) => mergeTranscriptItems(prev, [{ type: "session_marker", event, roomId, ts: markerTs }]));
  }, [roomId, mergeTranscriptItems, roomStartedMarkerTs]);

  // Keep a stable ref so the WS effect can call the latest appendSessionMarker
  // without needing it in the dep array (which would cause reconnects).
  useEffect(() => { appendSessionMarkerRef.current = appendSessionMarker; }, [appendSessionMarker]);

  const buildCombinedTranscript = useCallback(async (tokenValue: string, currentRoomId: string, currentPeerSessionId: string, fallbackPeerUsername?: string | null) => {
    const roomsRes = await api.getChatRooms(tokenValue);
    const relatedRooms = roomsRes.rooms
      .filter((room) => {
        if (currentPeerSessionId) return room.peer_session_id === currentPeerSessionId;
        if (fallbackPeerUsername) return room.peer_username === fallbackPeerUsername;
        return room.room_id === currentRoomId;
      })
      .sort((a, b) => getRoomSortTs(a) - getRoomSortTs(b));

    const roomDetails = await Promise.all(
      relatedRooms.map(async (room) => {
        try {
          return await api.getRoomMessages(tokenValue, room.room_id);
        } catch {
          return null;
        }
      })
    );

    const transcript: TranscriptItem[] = [];
    for (const detail of roomDetails) {
      if (!detail) continue;
      const startedMarkerTs = Number(detail.matched_at || detail.started_at || 0);
      if (startedMarkerTs) {
        transcript.push({ type: "session_marker", event: "started", roomId: detail.room_id, ts: startedMarkerTs });
      }
      transcript.push(...detail.messages);
      if (detail.ended_at) {
        transcript.push({ type: "session_marker", event: "ended", roomId: detail.room_id, ts: Number(detail.ended_at) });
      }
    }

    return transcript;
  }, []);

  const syncLiveRoomMessages = useCallback(async () => {
    if (!token || !roomId) return;

    const data = await api.getRoomMessages(token, roomId);
    if (data.peer_username) setPeerUsername(data.peer_username);
    if (data.peer_avatar_id != null) setPeerAvatarId(data.peer_avatar_id);
    if (data.peer_session_id) setResolvedPeerSessionId(data.peer_session_id);
    setRoomStartedMarkerTs(Number(data.matched_at || data.started_at || 0) || null);
    const durationSeconds = Number(data.duration || 15 * 60);

    if (data.started_at) {
      const elapsed = Math.max(0, Math.floor(Date.now() / 1000) - Number(data.started_at));
      setRemaining(Math.max(0, durationSeconds - elapsed));
      setTimerStarted(true);
    } else {
      setRemaining(durationSeconds);
      setTimerStarted(false);
    }

    setMessages((prev) => mergeTranscriptItems(prev, data.messages));

    if (data.status === "ended") {
      if (data.ended_at) {
        appendSessionMarker("ended", Number(data.ended_at));
      }
      setMode("readonly");
    }
  }, [token, roomId, mergeTranscriptItems, appendSessionMarker]);

  // Redirect guards
  useEffect(() => {
    if (!_hasHydrated) return;
    if (!token) { router.push("/verify"); return; }
    if (!username) { router.push("/profile"); return; }
    if (!roomId) { router.push("/lobby"); return; }
  }, [_hasHydrated, token, username, roomId, router]);

  useEffect(() => {
    setMessages([]);
    setRoomStartedMarkerTs(null);
    setPeerTyping(false);
    setPeerLeft(false);
    setSessionEnded(false);
    setConnectionError("");
  }, [roomId]);

  // Pre-check room status before opening WebSocket
  useEffect(() => {
    if (!token || !roomId) return;
    api.getRoomMessages(token, roomId)
      .then(async (data) => {
        if (data.status === "ended") {
          const transcript = await buildCombinedTranscript(token, roomId, peerSessionId || data.peer_session_id || "", data.peer_username);
          setMessages(transcript.length > 0 ? transcript : data.messages);
          setRoomStartedMarkerTs(Number(data.matched_at || data.started_at || 0) || null);
          if (data.peer_username) setPeerUsername(data.peer_username);
          if (data.peer_avatar_id != null) setPeerAvatarId(data.peer_avatar_id);
          setTimerStarted(Boolean(data.started_at));
          setMode("readonly");
        } else {
          const transcript = await buildCombinedTranscript(token, roomId, peerSessionId || data.peer_session_id || "", data.peer_username);
          setMessages(transcript.length > 0 ? transcript : data.messages);
          setRoomStartedMarkerTs(Number(data.matched_at || data.started_at || 0) || null);
          if (data.peer_username) setPeerUsername(data.peer_username);
          if (data.peer_avatar_id != null) setPeerAvatarId(data.peer_avatar_id);
          const durationSeconds = Number(data.duration || 15 * 60);
          if (data.started_at) {
            const elapsed = Math.max(0, Math.floor(Date.now() / 1000) - Number(data.started_at));
            setRemaining(Math.max(0, durationSeconds - elapsed));
            setTimerStarted(true);
          } else {
            setRemaining(durationSeconds);
            setTimerStarted(false);
          }
          setMode("live");
        }
      })
      .catch(() => setMode("expired"));
  }, [token, roomId, peerSessionId, buildCombinedTranscript]);

  // Connect WebSocket (live mode only)
  useEffect(() => {
    if (!token || !roomId || mode !== "live") return;

    const ws = new WebSocket(wsUrl.chat(token, roomId));
    wsRef.current = ws;

    ws.onopen = () => setConnected(true);

    ws.onmessage = (event) => {
      const data: WsEvent = JSON.parse(event.data);

      if ("room_id" in data && data.room_id && data.room_id !== roomId) {
        return;
      }

      switch (data.type) {
        case "history":
          // Always merge — never overwrite. Prevents stale-closure race where
          // a replace wipes optimistic messages or hides peer messages already
          // added by the polling sync.
          setMessages((prev) => mergeTranscriptItems(prev, data.messages));
          if (data.messages.length > 0 && username) {
            const peer = data.messages.find((m) => m.from !== username);
            if (peer) setPeerUsername(peer.from);
          }
          break;

        case "message":
          setMessages((prev) => mergeTranscriptItems(prev, [data as ChatMessage]));
          if (data.from !== username) {
            setPeerUsername(data.from);
            setPeerTyping(false);
          }
          break;

        case "typing_start":
          if (data.from !== username) { setPeerUsername(data.from); setPeerTyping(true); }
          break;

        case "typing_stop":
          if (data.from !== username) setPeerTyping(false);
          break;

        case "timer_status":
          if (data.started && !timerStartedRef.current) {
            appendSessionMarkerRef.current("started");
          }
          setTimerStarted(data.started);
          setRemaining(data.remaining);
          break;

        case "tick":
          if (!timerStartedRef.current) {
            appendSessionMarkerRef.current("started");
          }
          setTimerStarted(true);
          setRemaining(data.remaining);
          break;

        case "session_end":
          appendSessionMarkerRef.current("ended");
          setSessionEnded(true);
          break;

        case "peer_left":
          appendSessionMarkerRef.current("ended");
          setPeerLeft(true);
          setCanExtend(false);
          setSessionEnded(true);
          break;

        case "extended":
          setRemaining(data.remaining);
          setCanExtend(false);
          setSessionEnded(false);
          break;

        case "error":
          setConnectionError(data.detail);
          break;
      }
    };

    ws.onerror = () => {};
    ws.onclose = (ev) => {
      setConnected(false);
      if (ev.code === 4010) {
        api.getRoomMessages(token!, roomId).then((data) => {
          setMessages(data.messages);
          if (data.peer_username) setPeerUsername(data.peer_username);
          if (data.started_at) {
            const durationSeconds = Number(data.duration || 15 * 60);
            const elapsed = Math.max(0, Math.floor(Date.now() / 1000) - Number(data.started_at));
            setRemaining(Math.max(0, durationSeconds - elapsed));
            setTimerStarted(true);
          }
          setMode("readonly");
        }).catch(() => setMode("expired"));
      }
    };

    return () => { ws.close(); };
  // appendSessionMarker intentionally excluded — use appendSessionMarkerRef.current instead
  // to prevent reconnect whenever roomStartedMarkerTs changes.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, roomId, username, mode]);

  useEffect(() => {
    if (!token || !roomId || mode !== "live") return;

    const intervalId = window.setInterval(() => {
      syncLiveRoomMessages().catch(() => {});
    }, 1500);

    return () => window.clearInterval(intervalId);
  }, [token, roomId, mode, syncLiveRoomMessages]);

  // Auto-scroll only when already near the bottom so manual scrolling up isn't interrupted
  const isNearBottom = () => {
    const el = messagesContainerRef.current;
    if (!el) return true;
    return el.scrollHeight - el.scrollTop - el.clientHeight < 120;
  };

  useEffect(() => {
    if (isNearBottom()) {
      bottomRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, peerTyping]);

  const send = useCallback(() => {
    const text = input.trim();
    if (!text || !wsRef.current || !username) return;
    const clientId = `msg-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const optimisticMessage: ChatMessage = {
      type: "message",
      from: username,
      text,
      ts: Math.floor(Date.now() / 1000),
      client_id: clientId,
    };
    setMessages((prev) => mergeTranscriptItems(prev, [optimisticMessage]));
    wsRef.current.send(JSON.stringify({ type: "message", text, client_id: clientId }));
    setInput("");
    if (isTypingRef.current) {
      isTypingRef.current = false;
      wsRef.current.send(JSON.stringify({ type: "typing_stop" }));
    }
  }, [input, mergeTranscriptItems, username]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setInput(e.target.value);
    const ws = wsRef.current;
    if (!ws) return;
    if (!isTypingRef.current) {
      isTypingRef.current = true;
      ws.send(JSON.stringify({ type: "typing_start" }));
    }
    if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    typingTimeoutRef.current = setTimeout(() => {
      isTypingRef.current = false;
      ws.send(JSON.stringify({ type: "typing_stop" }));
    }, 1500);
  };

  const handleExtend = () => {
    wsRef.current?.send(JSON.stringify({ type: "extend" }));
    setSessionEnded(false);
  };

  const handleBlock = async () => {
    if (!token || !resolvedPeerSessionId || blocking || blocked) return;
    setBlocking(true);
    try {
      await api.blockUser(token, resolvedPeerSessionId, peerUsername ?? "", peerAvatarId);
      setBlocked(true);
      router.push("/lobby");
    } catch {
      // silently ignore
    } finally {
      setBlocking(false);
    }
  };

  const formatRemaining = (totalSeconds: number) => {
    const mins = Math.floor(totalSeconds / 60);
    const secs = totalSeconds % 60;
    return `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  };

  const formatTime = (ts: number) =>
    new Date(ts * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

  return (
    <div className="chat-shell" style={{
      display: "flex", flexDirection: "column", height: "100vh",
      background: "var(--ink)", color: "var(--white)",
      position: "relative", overflow: "hidden",
    }}>
      {/* Ambient orbs */}
      <div className="orb orb-c" style={{ position: "fixed", opacity: 0.3 }} />

      {/* Header */}
      <header className="chat-header" style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "12px 20px",
        background: "rgba(13,13,15,0.85)",
        backdropFilter: "blur(20px)",
        borderBottom: "1px solid rgba(255,255,255,0.06)",
        flexShrink: 0, position: "relative", zIndex: 10,
      }}>
        <div className="chat-meta" style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <FlowLogo />
        </div>

        {peerUsername && (
          <div className="chat-peer" style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", display: "flex", alignItems: "center", gap: 10 }}>
            <button
              onClick={() => peerUsername && setShowPeerProfile(true)}
              style={{ background: "none", border: "none", cursor: "pointer", padding: 0 }}
            >
              <img
                src={avatarUrl(peerAvatarId, 72)}
                alt="peer avatar"
                width={36} height={36}
                style={{ borderRadius: "50%", border: "2px solid rgba(184,160,232,0.3)" }}
              />
            </button>
            <div>
              <button
                onClick={() => peerUsername && setShowPeerProfile(true)}
                style={{
                  background: "none", border: "none", cursor: peerUsername ? "pointer" : "default",
                  fontWeight: 600, fontSize: 14, color: "var(--white)",
                  fontFamily: "var(--font-ui)", padding: 0, display: "block",
                }}
              >
                {peerUsername}
              </button>
              <p style={{ margin: 0, fontSize: 11, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                {mode === "readonly" ? "Past conversations" : connected ? "Live · anonymous" : "Connecting…"}
              </p>
            </div>
            {peerLeft && (
              <span style={{ fontSize: 11, color: "var(--danger)", fontFamily: "var(--font-ui)" }}>disconnected</span>
            )}
          </div>
        )}
        {!peerUsername && (
          <span style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
            {mode === "checking" ? "Loading…" : "Waiting for someone…"}
          </span>
        )}

        <div className="chat-header-right" style={{ display: "flex", alignItems: "center", gap: 12 }}>
          {mode === "live" && (<>
            {timerStarted ? (
              <Timer remainingSeconds={remaining} onEnd={() => setSessionEnded(true)} />
            ) : (
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  padding: "6px 14px",
                  background: "rgba(184,160,232,0.08)",
                  border: "1px solid rgba(184,160,232,0.18)",
                  borderRadius: "var(--r-full)",
                  fontFamily: "var(--font-ui)",
                  fontSize: 13,
                  fontWeight: 600,
                  color: "var(--accent)",
                  letterSpacing: "0.05em",
                  opacity: 0.9,
                }}
                aria-label="15 minutes available once the conversation begins"
              >
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <circle cx="12" cy="12" r="10" />
                  <polyline points="12 6 12 12 16 14" strokeLinecap="round" />
                </svg>
                {formatRemaining(remaining)}
              </div>
            )}
            {(peerLeft || !connected) && (
              <span className="pill" style={{ background: "rgba(255,255,255,0.05)", color: "var(--fog)", border: "1px solid rgba(255,255,255,0.08)" }}>
                {peerLeft ? "Peer left" : "Connecting"}
              </span>
            )}
            <button
              onClick={() => setShowReport(true)}
              style={{ background: "none", border: "none", color: "var(--slate)", cursor: "pointer", fontSize: 16, padding: "4px 8px" }}
              title="Report"
            >
              ⚑
            </button>
            {confirmingBlock ? (
              <span style={{ display: "flex", alignItems: "center", gap: 4, fontFamily: "var(--font-ui)", fontSize: 11 }}>
                <span style={{ color: "var(--danger)" }}>Block?</span>
                <button
                  onClick={() => { setConfirmingBlock(false); void handleBlock(); }}
                  style={{ background: "none", border: "none", cursor: "pointer", color: "var(--danger)", fontSize: 14, padding: "2px 4px", lineHeight: 1 }}
                >
                  ✓
                </button>
                <button
                  onClick={() => setConfirmingBlock(false)}
                  style={{ background: "none", border: "none", cursor: "pointer", color: "var(--slate)", fontSize: 14, padding: "2px 4px", lineHeight: 1 }}
                >
                  ✗
                </button>
              </span>
            ) : (
              <button
                onClick={() => setConfirmingBlock(true)}
                disabled={blocking || blocked}
                title={blocked ? "Blocked" : "Block user"}
                style={{
                  background: "none", border: "none",
                  cursor: blocking || blocked ? "default" : "pointer",
                  fontSize: 15, padding: "4px 6px",
                  color: blocked ? "var(--graphite)" : "var(--slate)",
                  opacity: blocking ? 0.5 : 1,
                  lineHeight: 1,
                }}
              >
                ⛔
              </button>
            )}
            <button
              onClick={() => { wsRef.current?.send(JSON.stringify({ type: "leave" })); router.push("/lobby"); }}
              style={{
                padding: "7px 14px", borderRadius: "var(--r-full)",
                background: "none", border: "1px solid rgba(232,128,128,0.3)",
                color: "var(--danger)", fontSize: 12, fontWeight: 600,
                cursor: "pointer", fontFamily: "var(--font-ui)",
              }}
            >
              Leave
            </button>
          </>)}
          <button
            onClick={() => router.push("/lobby")}
            className="btn btn-sm btn-ghost"
            title="Back to lobby"
          >
            ←
          </button>
        </div>
      </header>

      {/* Messages */}
      <div ref={messagesContainerRef} className="chat-messages" style={{ flex: 1, overflowY: "auto", padding: "20px 20px", display: "flex", flexDirection: "column", gap: 10, position: "relative", zIndex: 2 }}>
        {mode === "live" && !peerLeft && (
          <div style={{ textAlign: "center", paddingBottom: 6 }}>
            <span className="pill" style={{ fontSize: 11, background: "rgba(255,255,255,0.04)", color: "var(--fog)", border: "1px solid rgba(255,255,255,0.08)" }}>
              {timerStarted
                ? "Listen first. Respond honestly."
                : "Listen first. Respond honestly."}
            </span>
          </div>
        )}

        {connectionError && mode === "live" && (
          <div style={{ textAlign: "center", fontSize: 13, color: "var(--danger)", background: "rgba(232,128,128,0.08)", border: "1px solid rgba(232,128,128,0.2)", borderRadius: "var(--r-md)", padding: "12px 16px", fontFamily: "var(--font-ui)" }}>
            {connectionError}
          </div>
        )}

        {peerLeft && (
          <div style={{ textAlign: "center", fontSize: 13, color: "var(--slate)", background: "rgba(255,255,255,0.04)", borderRadius: "var(--r-md)", padding: "12px 16px", fontFamily: "var(--font-ui)" }}>
            Chat ended. The other person left the room. You can head back to the lobby whenever you&apos;re ready.
          </div>
        )}

        {mode === "checking" && messages.length === 0 && (
          <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ width: 24, height: 24, borderRadius: "50%", border: "2px solid rgba(184,160,232,0.3)", borderTopColor: "var(--accent)", animation: "logo-spin 0.8s linear infinite" }} />
          </div>
        )}

        {mode === "expired" && (
          <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", gap: 12 }}>
            <p style={{ fontFamily: "var(--font-display)", fontSize: 48, color: "rgba(255,255,255,0.1)", fontWeight: 900, letterSpacing: "-0.04em" }}>404</p>
            <p style={{ fontWeight: 600, color: "var(--fog)", fontFamily: "var(--font-ui)" }}>Conversation no longer available.</p>
            <p style={{ fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>This chat has expired.</p>
          </div>
        )}

        {messages.length === 0 && mode === "live" && !peerLeft && connected && (
          <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", color: "var(--slate)", fontSize: 14, fontFamily: "var(--font-ui)", fontWeight: 300 }}>
            This is your space. Take your time.
          </div>
        )}

        {messages.map((msg, i) => {
          if (msg.type === "session_marker") {
            const label = msg.event === "started" ? "Chat started" : "Chat ended";
            return (
              <div key={`${msg.roomId}-${msg.event}-${msg.ts}-${i}`} style={{ display: "flex", justifyContent: "center", padding: "6px 0" }}>
                <div style={{ padding: "8px 12px", borderRadius: "var(--r-full)", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)", fontFamily: "var(--font-ui)", fontSize: 11, color: "var(--fog)", display: "inline-flex", gap: 8, alignItems: "center" }}>
                  <span>{label}</span>
                  <span style={{ color: "var(--graphite)" }}>{formatTime(msg.ts)}</span>
                </div>
              </div>
            );
          }

          // If we know the peer, use peer-exclusion — more reliable than comparing
          // against the Zustand username which can be stale after a re-roll.
          const isMe = peerUsername
            ? msg.from !== peerUsername
            : msg.from === username;
          return (
            <div key={i} className="msg-enter" style={{ display: "flex", flexDirection: "column", alignItems: isMe ? "flex-end" : "flex-start" }}>
              {!isMe && (
                <span style={{ fontSize: 11, color: "var(--slate)", marginBottom: 4, paddingLeft: 4, fontFamily: "var(--font-ui)" }}>{msg.from}</span>
              )}
              <div className="chat-bubble" style={{
                maxWidth: "72%",
                padding: "10px 16px",
                borderRadius: isMe ? "20px 20px 4px 20px" : "20px 20px 20px 4px",
                fontSize: 14, lineHeight: 1.55,
                fontFamily: "var(--font-ui)", fontWeight: 300,
                ...(isMe
                  ? { background: "var(--charcoal)", color: "var(--white)", border: "1px solid rgba(255,255,255,0.08)" }
                  : { background: "rgba(255,255,255,0.08)", color: "var(--fog)", border: "1px solid rgba(255,255,255,0.1)", backdropFilter: "blur(8px)" }
                ),
              }}>
                {msg.text}
              </div>
              <span style={{ fontSize: 10, color: "var(--graphite)", padding: "3px 4px", fontFamily: "var(--font-ui)" }}>
                {formatTime(msg.ts)}
              </span>
            </div>
          );
        })}

        {peerTyping && peerUsername && <TypingIndicator username={peerUsername} />}

        <div ref={bottomRef} />
      </div>

      {/* Input bar (live only) */}
      {mode === "live" && (
        <div className="chat-input-wrap" style={{
          flexShrink: 0, padding: "12px 20px 16px",
          background: "rgba(13,13,15,0.9)",
          backdropFilter: "blur(16px)",
          borderTop: "1px solid rgba(255,255,255,0.06)",
          position: "relative", zIndex: 10,
        }}>
          <div className="chat-input-row" style={{ display: "flex", gap: 10, alignItems: "flex-end", maxWidth: 760, margin: "0 auto" }}>
            <textarea
              value={input}
              onChange={handleInputChange}
              onKeyDown={handleKeyDown}
              disabled={!connected || peerLeft || sessionEnded}
              placeholder={peerLeft ? "Chat ended" : !connected ? "Connecting…" : "Say something…"}
              rows={1}
              className="flow-input"
              style={{
                flex: 1, resize: "none", maxHeight: 128, overflowY: "auto",
                lineHeight: 1.5, opacity: (!connected || peerLeft || sessionEnded) ? 0.5 : 1,
              }}
            />
            <button
              onClick={send}
              disabled={!input.trim() || !connected || peerLeft}
              className="chat-send"
              style={{
                padding: "13px 18px", borderRadius: "var(--r-md)",
                background: "var(--accent)",
                border: "none", color: "var(--ink)",
                fontSize: 16, cursor: "pointer",
                transition: "opacity 0.15s",
                opacity: (!input.trim() || !connected || peerLeft) ? 0.35 : 1,
                flexShrink: 0,
              }}
              aria-label="Send message"
            >
              ↑
            </button>
          </div>
          <p style={{ textAlign: "center", fontSize: 10, color: "var(--graphite)", marginTop: 6, fontFamily: "var(--font-ui)" }}>
            Enter to send · Shift+Enter for new line · Leave any time
          </p>
        </div>
      )}

      {/* Readonly/expired footer */}
      {(mode === "readonly" || mode === "expired") && (
        <div className="chat-footer-actions" style={{
          flexShrink: 0, padding: "14px 20px",
          background: "rgba(13,13,15,0.9)", backdropFilter: "blur(16px)",
          borderTop: "1px solid rgba(255,255,255,0.06)",
          display: "flex", alignItems: "center", justifyContent: "center", gap: 12,
          position: "relative", zIndex: 10,
        }}>
          {confirmingBlock ? (
            <>
              <span style={{ fontSize: 12, color: "var(--danger)", fontFamily: "var(--font-ui)", fontWeight: 600 }}>Block this person?</span>
              <button onClick={() => { setConfirmingBlock(false); void handleBlock(); }} className="btn btn-sm btn-ghost" style={{ color: "var(--danger)" }}>
                Yes
              </button>
              <button onClick={() => setConfirmingBlock(false)} className="btn btn-sm btn-ghost">
                No
              </button>
            </>
          ) : (
            <button
              onClick={() => setConfirmingBlock(true)}
              disabled={blocking || blocked || !resolvedPeerSessionId}
              className="btn btn-sm btn-ghost"
              style={{ color: blocked ? "var(--graphite)" : "var(--danger)", opacity: (!resolvedPeerSessionId || blocked) ? 0.4 : 1 }}
            >
              {blocked ? "Blocked" : blocking ? "Blocking…" : "Block"}
            </button>
          )}
          <button
            onClick={() => router.push("/lobby")}
            className="btn btn-sm btn-ghost"
          >
            ← Back to lobby
          </button>
          <button
            onClick={() => setShowReport(true)}
            className="btn btn-sm btn-ghost"
            style={{ color: "var(--danger)" }}
          >
            Report
          </button>
        </div>
      )}

      {/* Modals */}
      {sessionEnded && (
        <SessionEndModal canExtend={canExtend} onExtend={handleExtend} onClose={() => setSessionEnded(false)} />
      )}
      {showReport && <ReportModal onClose={() => setShowReport(false)} />}
      {showPeerProfile && peerUsername && token && (
        <UserProfileModal
          username={peerUsername}
          token={token}
          peerSessionId={resolvedPeerSessionId || undefined}
          roomId={roomId || undefined}
          onClose={() => setShowPeerProfile(false)}
          onBlocked={() => { setShowPeerProfile(false); setSessionEnded(false); router.push("/lobby"); }}
        />
      )}
    </div>
  );
}

export default function ChatPage() {
  return (
    <Suspense fallback={
      <div style={{ height: "100vh", display: "flex", alignItems: "center", justifyContent: "center", background: "var(--ink)" }}>
        <div style={{ width: 32, height: 32, borderRadius: "50%", border: "2px solid rgba(184,160,232,0.2)", borderTopColor: "var(--accent)", animation: "logo-spin 0.8s linear infinite" }} />
      </div>
    }>
      <ChatContent />
    </Suspense>
  );
}

