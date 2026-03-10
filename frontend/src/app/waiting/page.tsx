"use client";

import { useCallback, useEffect, useRef } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthStore } from "@/store/authStore";
import { api, wsUrl } from "@/lib/api";
import { FlowLogo } from "@/components/FlowLogo";
import { Suspense } from "react";

function WaitingInner() {
  const router = useRouter();
  const params = useSearchParams();
  const { token, clear } = useAuthStore();
  const requestId = params.get("request_id");

  const wsRef = useRef<WebSocket | null>(null);

  const connectWs = useCallback(() => {
    if (!token) return;
    const ws = new WebSocket(wsUrl.board(token));
    wsRef.current = ws;

    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.event === "error" && msg.detail === "token_invalid") { ws.close(); clear(); router.push("/verify"); return; }
      if (msg.event === "matched") { ws.close(); router.push(`/chat?room_id=${encodeURIComponent(msg.room_id)}`); }
    };

    ws.onclose = (ev) => {
      if (ev.code === 4401) { clear(); router.push("/verify"); return; }
      setTimeout(() => { if (document.visibilityState !== "hidden") connectWs(); }, 3000);
    };
  }, [token, router, clear]);

  useEffect(() => {
    if (!token) { router.push("/verify"); return; }
    if (!requestId) { router.push("/lobby"); return; }
    connectWs();
    return () => wsRef.current?.close();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, requestId]);

  const handleCancel = async () => {
    if (!token) return;
    try { await api.cancelSpeak(token); } catch { /* swallow */ }
    wsRef.current?.close();
    router.push("/lobby");
  };

  return (
    <div className="dark-canvas grain" style={{ minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", position: "relative" }}>
      <div className="orb orb-a" />
      <div className="orb orb-b" />
      <div className="orb orb-c" />

      {/* Nav */}
      <div style={{ position: "fixed", top: 0, left: 0, right: 0, padding: "24px 32px", zIndex: 10 }}>
        <FlowLogo />
      </div>

      {/* Central content */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 32, textAlign: "center", position: "relative", zIndex: 5 }}>
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
          <span className="pill pill-accent" style={{ marginBottom: 16, display: "inline-flex" }}>
            <span className="pill-dot" />
            Finding your guide
          </span>
          <h1 className="t-display" style={{ color: "var(--white)", marginBottom: 12 }}>
            Your space<br />is <em style={{ color: "var(--accent)" }}>ready.</em>
          </h1>
          <p style={{
            fontSize: 15, fontWeight: 300, color: "var(--slate)",
            maxWidth: 300, lineHeight: 1.6, margin: "0 auto",
            fontFamily: "var(--font-ui)",
          }}>
            An anchor is on their way.<br />Take a breath - you&apos;re not alone.
          </p>
        </div>

        <button
          onClick={handleCancel}
          className="btn btn-ghost"
          style={{ fontSize: 13 }}
        >
          Cancel and go back
        </button>
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
