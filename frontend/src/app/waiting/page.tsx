"use client";

import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthStore } from "@/store/authStore";
import { api, wsUrl, AuthError } from "@/lib/api";
import { FlowLogo } from "@/components/FlowLogo";
import { Timer } from "@/components/Timer";
import { useAuthGuard } from "@/lib/useAuthGuard";


const WAIT_WINDOW_SECONDS = 10 * 60;

function WaitingInner() {
  const router = useRouter();
  const params = useSearchParams();
  const { token, clear, _hasHydrated } = useAuthStore();
  const requestId = params.get("request_id");
  const lobbyWhileWaitingHref = requestId
    ? `/lobby?request_id=${encodeURIComponent(requestId)}`
    : "/lobby";

  const wsRef = useRef<WebSocket | null>(null);
  const timeoutHandledRef = useRef(false);
  const reconnectTimeoutRef = useRef<number | null>(null);

  const [remaining, setRemaining] = useState(WAIT_WINDOW_SECONDS);
  const [timedOut, setTimedOut] = useState(false);
  const [loadingRequest, setLoadingRequest] = useState(true);
  const [retrying, setRetrying] = useState(false);
  const [requestMissing, setRequestMissing] = useState(false);

  const handleTimeout = useCallback(async () => {
    if (!token || timeoutHandledRef.current) return;
    timeoutHandledRef.current = true;
    setTimedOut(true);
    wsRef.current?.close();
    try {
      await api.cancelSpeak(token);
    } catch {
      /* swallow */
    }
  }, [token]);

  const openMatchedRoom = useCallback((roomId: string) => {
    wsRef.current?.close();
    router.push(`/chat?room_id=${encodeURIComponent(roomId)}`);
  }, [router]);

  const syncRequestStatus = useCallback(async () => {
    if (!token || !requestId) {
      return { matched: false, active: false };
    }

    try {
      setRequestMissing(false);
      const request = await api.getSpeakerRequest(token, requestId);
      if (request.status === "matched" && request.room_id) {
        openMatchedRoom(request.room_id);
        return { matched: true, active: false };
      }

      if (!request.posted_at) {
        return { matched: false, active: false };
      }

      const elapsed = Math.max(0, Math.floor(Date.now() / 1000) - Number(request.posted_at));
      const nextRemaining = Math.max(0, WAIT_WINDOW_SECONDS - elapsed);
      setRemaining(nextRemaining);
      if (nextRemaining === 0) {
        void handleTimeout();
        return { matched: false, active: false };
      }

      return { matched: false, active: true };
    } catch {
      setRequestMissing(true);
      return { matched: false, active: false };
    }
  }, [token, requestId, openMatchedRoom, handleTimeout]);

  const connectWs = useCallback(() => {
    if (!token || timedOut) return;
    const ws = new WebSocket(wsUrl.board(token));
    wsRef.current = ws;

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.event === "error" && msg.detail === "token_invalid") { ws.close(); clear(); router.push("/verify"); return; }
      if (msg.event === "board_state" && !msg.my_request_id) {
        syncRequestStatus().then((status) => {
          if (!status.matched && !status.active) {
            setTimedOut(true);
          }
        }).catch(() => {});
        return;
      }
      if (msg.event === "matched") {
        openMatchedRoom(msg.room_id);
      }
    };

    ws.onclose = (ev) => {
      if (ev.code === 4401) { clear(); router.push("/verify"); return; }
      if (reconnectTimeoutRef.current !== null) {
        window.clearTimeout(reconnectTimeoutRef.current);
      }
      reconnectTimeoutRef.current = window.setTimeout(() => {
        if (!timedOut && document.visibilityState !== "hidden") connectWs();
      }, 3000);
    };
  }, [token, router, clear, timedOut, syncRequestStatus, openMatchedRoom]);

  useAuthGuard();

  useEffect(() => {
    if (!_hasHydrated) return;
    if (!token) return;
    if (!requestId) { router.push("/lobby"); return; }

    let cancelled = false;
    timeoutHandledRef.current = false;
    setLoadingRequest(true);
    setTimedOut(false);
    setRetrying(false);
    setRequestMissing(false);

    syncRequestStatus()
      .then((status) => {
        if (cancelled || status.matched) return;
        if (!status.active) {
          setTimedOut(true);
          return;
        }
        connectWs();
      })
      .catch(() => {
        if (cancelled) return;
        setTimedOut(true);
      })
      .finally(() => {
        if (!cancelled) setLoadingRequest(false);
      });

    return () => {
      cancelled = true;
      if (reconnectTimeoutRef.current !== null) {
        window.clearTimeout(reconnectTimeoutRef.current);
      }
      wsRef.current?.close();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [_hasHydrated, token, requestId, syncRequestStatus, connectWs]);

  const handleMinimize = useCallback(() => {
    if (reconnectTimeoutRef.current !== null) {
      window.clearTimeout(reconnectTimeoutRef.current);
    }
    wsRef.current?.close();
    router.push(lobbyWhileWaitingHref);
  }, [router, lobbyWhileWaitingHref, reconnectTimeoutRef, wsRef]);

  // ESC minimizes the waiting page
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") handleMinimize(); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [handleMinimize]);

  const handleCancel = async () => {
    if (!token) return;
    try { await api.cancelSpeak(token); } catch { /* swallow */ }
    wsRef.current?.close();
    router.push("/lobby");
  };

  const handleRetry = async () => {
    if (!token) return;
    setRetrying(true);
    try {
      const res = await api.postSpeak(token);
      setRemaining(WAIT_WINDOW_SECONDS);
      setTimedOut(false);
      timeoutHandledRef.current = false;
      router.replace(`/waiting?request_id=${encodeURIComponent(res.request_id)}`);
    } catch (e) {
      if (e instanceof AuthError) { clear(); router.push("/verify"); return; }
      setRetrying(false);
    }
  };

  useEffect(() => {
    if (!timedOut) return;
    wsRef.current?.close();
  }, [timedOut]);

  useEffect(() => {
    if (!token || timedOut || requestMissing) return;

    const intervalId = window.setInterval(() => {
      syncRequestStatus().then((status) => {
        if (!status.matched && !status.active) {
          setTimedOut(true);
        }
      }).catch(() => {});
    }, 1000);

    return () => window.clearInterval(intervalId);
  }, [token, timedOut, requestMissing, syncRequestStatus]);

  const waitingCopy = (
    <>
      <span className="pill pill-accent" style={{ marginBottom: 16, display: "inline-flex" }}>
        <span className="pill-dot" />
        Finding someone
      </span>
      <h1 className="t-display" style={{ color: "var(--white)", marginBottom: 12 }}>
        Your space<br />is <em style={{ color: "var(--accent)" }}>ready.</em>
      </h1>
      <p style={{
        fontSize: 15, fontWeight: 300, color: "var(--slate)",
        maxWidth: 320, lineHeight: 1.6, margin: "0 auto 18px",
        fontFamily: "var(--font-ui)",
      }}>
        Someone will be here soon.
      </p>
      {!timedOut && !loadingRequest && (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
          <Timer remainingSeconds={remaining} onEnd={() => { void handleTimeout(); }} />
          <p style={{ margin: 0, fontSize: 12, color: "var(--mist)", fontFamily: "var(--font-ui)" }}>
            Most connections happen within the first few minutes.
          </p>
          <p style={{ margin: 0, fontSize: 12, color: "var(--graphite)", fontFamily: "var(--font-ui)" }}>
            If time runs out, you can raise the request again.
          </p>
        </div>
      )}
    </>
  );

  return (
    <div className="dark-canvas grain waiting-shell" style={{ minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", position: "relative" }}>
      <div className="orb orb-a" />
      <div className="orb orb-b" />
      <div className="orb orb-c" />

      {/* Nav */}
      <div className="top-nav" style={{ position: "fixed", top: 0, left: 0, right: 0, padding: "24px 32px", zIndex: 10 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16 }}>
          <FlowLogo />
          {!timedOut && !loadingRequest && (
            <button
              onClick={handleMinimize}
              className="btn btn-sm btn-ghost"
              title="Back to lobby (Esc)"
            >
              ←
            </button>
          )}
        </div>
      </div>

      {/* Central content */}
      <div className="waiting-card" style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 32, textAlign: "center", position: "relative", zIndex: 5 }}>
        {/* Breathing orb */}
        <div style={{ position: "relative", width: 140, height: 140 }}>
          {/* Outer rings */}
          <div style={{
            position: "absolute",
            top: "50%", left: "50%",
            transform: "translate(-50%, -50%)",
            width: 200, height: 200,
            borderRadius: "50%",
            border: "1px solid rgba(184,160,232,0.15)",
            animation: "w-breathe 4s ease-in-out infinite",
          }} />
          <div style={{
            position: "absolute",
            top: "50%", left: "50%",
            transform: "translate(-50%, -50%)",
            width: 170, height: 170,
            borderRadius: "50%",
            border: "1px solid rgba(184,160,232,0.2)",
            animation: "w-breathe 4s ease-in-out infinite 0.6s",
          }} />
          <div style={{
            position: "absolute",
            top: "50%", left: "50%",
            transform: "translate(-50%, -50%)",
            width: 140, height: 140,
            borderRadius: "50%",
            border: "1px solid rgba(184,160,232,0.25)",
            animation: "w-breathe 4s ease-in-out infinite 1.2s",
          }} />
          {/* Core */}
          <div style={{
            position: "absolute",
            top: "50%", left: "50%",
            transform: "translate(-50%, -50%)",
            width: 80, height: 80,
            borderRadius: "50%",
            background: "radial-gradient(circle, rgba(184,160,232,0.35) 0%, rgba(184,160,232,0.08) 100%)",
            border: "1px solid rgba(184,160,232,0.4)",
            animation: "w-core-pulse 4s ease-in-out infinite",
            boxShadow: "0 0 40px rgba(184,160,232,0.2)",
          }} />
          {/* Dot */}
          <div style={{
            position: "absolute",
            top: "50%", left: "50%",
            transform: "translate(-50%, -50%)",
            width: 8, height: 8,
            borderRadius: "50%",
            background: "var(--accent)",
            animation: "w-dot-blink 2s ease-in-out infinite",
            boxShadow: "0 0 12px var(--accent)",
          }} />
        </div>

          <div>
            {waitingCopy}
          </div>

          {!timedOut && !loadingRequest && (
            <div className="glass-card" style={{ width: "100%", maxWidth: 420, padding: "18px 20px", textAlign: "left" }}>
              <p className="t-label" style={{ marginBottom: 10 }}>What to expect</p>
              <div style={{ display: "grid", gap: 10 }}>
                <p style={{ fontSize: 13, color: "var(--fog)", lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                  One person joins at a time. When they arrive, you&apos;ll enter the conversation automatically.
                </p>
                <p style={{ fontSize: 13, color: "var(--fog)", lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
                  If this window ends without a match, you can raise the request again instantly.
                </p>
              </div>
            </div>
          )}

          {timedOut ? (
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 16, maxWidth: 400, width: "100%" }}>
              <div style={{ padding: "20px 24px", borderRadius: "var(--r-lg)", background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.08)", width: "100%", textAlign: "center" }}>
                <p style={{ margin: "0 0 8px", fontSize: 15, fontWeight: 600, color: "var(--white)", fontFamily: "var(--font-ui)" }}>
                  No one connected this time.
                </p>
                <p style={{ margin: 0, fontSize: 13, lineHeight: 1.6, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                  That&apos;s okay — you still showed up for yourself. Listeners are most active in the evenings.
                </p>
              </div>

              {/* Journal fallback */}
              <div style={{ width: "100%", padding: "18px 20px", borderRadius: "var(--r-lg)", background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
                <p style={{ margin: "0 0 10px", fontSize: 12, fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase", color: "var(--slate)", fontFamily: "var(--font-ui)" }}>
                  Write it out — just for you
                </p>
                <textarea
                  placeholder="Say what you wanted to say. No one sees this."
                  style={{
                    width: "100%", minHeight: 100, background: "transparent", border: "none",
                    outline: "none", resize: "none", fontSize: 14, color: "var(--white)",
                    fontFamily: "var(--font-ui)", lineHeight: 1.6, caretColor: "var(--accent)",
                  }}
                />
              </div>

              <div style={{ display: "flex", gap: 10, flexWrap: "wrap", justifyContent: "center" }}>
                <button onClick={handleRetry} className="btn btn-sm btn-ghost" disabled={retrying}>
                  {retrying ? "Raising request..." : "Try again →"}
                </button>
                <button onClick={() => router.push("/lobby")} className="btn btn-sm btn-ghost">
                  Back to lobby
                </button>
              </div>

              <p style={{ fontSize: 12, color: "var(--graphite)", fontFamily: "var(--font-ui)", textAlign: "center" }}>
                If you&apos;re struggling right now, you&apos;re not alone.{" "}
                <a href="https://iCall.iitb.ac.in" target="_blank" rel="noopener noreferrer" style={{ color: "var(--accent)" }}>
                  iCall (India)
                </a>{" "}
                ·{" "}
                <a href="https://www.befrienders.org" target="_blank" rel="noopener noreferrer" style={{ color: "var(--accent)" }}>
                  Befrienders worldwide
                </a>
              </p>
            </div>
          ) : (
            <button
              onClick={handleCancel}
              className="btn btn-sm btn-ghost"
            >
              Cancel
            </button>
          )}
      </div>
    </div>
  );
}

export default function WaitingPage() {
  return (
    <Suspense>
      <WaitingInner />
    </Suspense>
  );
}
