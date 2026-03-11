"use client";

import { useEffect, useState } from "react";
import { api, AuthError } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";
import { brand } from "@/lib/brand";

const REASONS = [
  { value: "harassment",            label: "Harassment" },
  { value: "spam",                  label: "Spam" },
  { value: "hate_speech",           label: "Hate speech" },
  { value: "inappropriate_content", label: "Inappropriate content" },
  { value: "underage_suspected",    label: "Suspected underage user" },
  { value: "other",                 label: "Other" },
];

// Rewritten with Flow dark glass style - logic unchanged

interface ReportModalProps { onClose: () => void; roomId?: string; }

export function ReportModal({ onClose, roomId }: ReportModalProps) {
  const { token } = useAuthStore();
  const [reason, setReason] = useState("");
  const [detail, setDetail] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  const submit = async () => {
    if (!reason || !token) return;
    try {
      await api.submitReport(token, reason, detail, roomId);
      setSubmitted(true);
    } catch (e: unknown) {
      if (e instanceof AuthError) {
        setError("Your session has expired. Please refresh the page to log back in.");
        return;
      }
      setError(e instanceof Error ? e.message : "Failed to submit report");
    }
  };

  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed", inset: 0, zIndex: 50,
        display: "flex", alignItems: "center", justifyContent: "center",
        background: "rgba(13,13,15,0.75)",
        backdropFilter: "blur(12px)",
        padding: "1rem",
      }}
    >
      <div className="glass-card" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 400, width: "100%", padding: 28 }}>
        {submitted ? (
          <div style={{ textAlign: "center", padding: "16px 0" }}>
            <p style={{ fontSize: 32, marginBottom: 8 }}>✓</p>
            <h3 style={{ fontFamily: "var(--font-display)", fontSize: 20, fontWeight: 700, color: "var(--white)", marginBottom: 6 }}>Report submitted</h3>
            <p style={{ fontSize: 13, color: "var(--slate)", fontWeight: 300, marginBottom: 20, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
              Thank you for helping keep {brand.appName} safe.
            </p>
            <button onClick={onClose} className="btn btn-accent btn-md" style={{ width: "100%" }}>Close</button>
          </div>
        ) : (
          <>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 20 }}>
              <h3 style={{ fontFamily: "var(--font-display)", fontSize: 20, fontWeight: 700, color: "var(--white)" }}>Report user</h3>
              <button onClick={onClose} style={{ background: "none", border: "none", fontSize: 22, color: "var(--slate)", cursor: "pointer" }}>×</button>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 8, marginBottom: 16 }}>
              {REASONS.map((r) => (
                <label key={r.value} style={{
                  display: "flex", alignItems: "center", gap: 12,
                  padding: "10px 14px", borderRadius: "var(--r-md)",
                  border: `1px solid ${reason === r.value ? "rgba(184,160,232,0.5)" : "rgba(255,255,255,0.08)"}`,
                  background: reason === r.value ? "var(--accent-glow)" : "transparent",
                  cursor: "pointer", transition: "all 0.15s",
                }}>
                  <input type="radio" name="reason" value={r.value} checked={reason === r.value} onChange={() => setReason(r.value)} style={{ accentColor: "var(--accent)" }} />
                  <span style={{ fontSize: 13, color: "var(--fog)", fontWeight: 300, fontFamily: "var(--font-ui)" }}>{r.label}</span>
                </label>
              ))}
            </div>
            <textarea
              placeholder="Additional details (optional)"
              value={detail}
              onChange={(e) => setDetail(e.target.value)}
              maxLength={500}
              rows={3}
              className="flow-input"
              style={{ width: "100%", resize: "none", marginBottom: 16, boxSizing: "border-box" as const }}
            />
            {error && <p style={{ fontSize: 12, color: "var(--danger)", marginBottom: 12, fontFamily: "var(--font-ui)" }}>{error}</p>}
            <div style={{ display: "flex", gap: 10 }}>
              <button onClick={onClose} className="btn btn-ghost btn-md" style={{ flex: 1 }}>Cancel</button>
              <button onClick={submit} disabled={!reason} className="btn btn-danger btn-md" style={{ flex: 1, opacity: reason ? 1 : 0.4 }}>Submit report</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

