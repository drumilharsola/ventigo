"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/store/authStore";

interface SessionEndModalProps {
  canExtend: boolean;
  canContinue: boolean;
  peerLeft: boolean;
  continueWaiting: boolean;
  onExtend: () => void;
  onContinue: () => void;
  onClose: () => void;
  onFeedback?: (mood: string) => void;
}

const MOODS = [
  { emoji: "😌", label: "Calm", value: "calm" },
  { emoji: "😊", label: "Better", value: "better" },
  { emoji: "😐", label: "Same", value: "same" },
  { emoji: "😔", label: "Worse", value: "worse" },
];

export function SessionEndModal({
  canExtend,
  canContinue,
  peerLeft,
  continueWaiting,
  onExtend,
  onContinue,
  onClose,
  onFeedback,
}: SessionEndModalProps) {
  const router = useRouter();
  const { clear } = useAuthStore();
  const [selectedMood, setSelectedMood] = useState<string | null>(null);

  const handleRematch = () => { onClose(); router.push("/lobby"); };
  const handleSignOut = () => { clear(); router.push("/"); };
  const handleMood = (mood: string) => {
    setSelectedMood(mood);
    onFeedback?.(mood);
  };

  return (
    <div style={{
      position: "fixed", inset: 0, zIndex: 50,
      display: "flex", alignItems: "center", justifyContent: "center",
      background: "rgba(13,13,15,0.75)",
      backdropFilter: "blur(12px)",
      padding: "1rem",
    }}>
      <div className="glass-card" style={{ maxWidth: 360, width: "100%", padding: "44px 36px", textAlign: "center" }}>
        <h2 style={{
          fontFamily: "var(--font-display)",
          fontSize: 28, fontWeight: 700, fontStyle: "italic",
          color: "var(--white)", marginBottom: 8,
          letterSpacing: "-0.02em",
        }}>
          {peerLeft ? "They had to go." : "Time\u2019s up."}
        </h2>
        <p style={{ fontSize: 14, color: "var(--slate)", fontWeight: 300, marginBottom: 24, lineHeight: 1.6, fontFamily: "var(--font-ui)" }}>
          {peerLeft
            ? "Your conversation mattered \u2014 even if it was brief."
            : "That conversation has dissolved. How are you feeling?"}
        </p>

        {/* Mood check */}
        {!peerLeft && (
          <div style={{ display: "flex", justifyContent: "center", gap: 12, marginBottom: 28 }}>
            {MOODS.map((m) => (
              <button
                key={m.value}
                onClick={() => handleMood(m.value)}
                style={{
                  display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
                  background: selectedMood === m.value ? "rgba(184,160,232,0.15)" : "transparent",
                  border: selectedMood === m.value ? "1px solid rgba(184,160,232,0.4)" : "1px solid transparent",
                  borderRadius: 12, padding: "8px 10px", cursor: "pointer",
                  transition: "all 0.2s",
                }}
              >
                <span style={{ fontSize: 24 }}>{m.emoji}</span>
                <span style={{ fontSize: 10, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>{m.label}</span>
              </button>
            ))}
          </div>
        )}

        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {/* Continue (mutual) */}
          {canContinue && !peerLeft && (
            <button
              onClick={onContinue}
              disabled={continueWaiting}
              className="btn btn-accent btn-md"
              style={{ width: "100%", opacity: continueWaiting ? 0.7 : 1 }}
            >
              {continueWaiting ? "Waiting for them\u2026" : "Continue chatting"}
            </button>
          )}

          {/* Extend */}
          {canExtend && !peerLeft && (
            <button onClick={onExtend} className="btn btn-accent btn-md" style={{
              width: "100%",
              background: canContinue ? "transparent" : undefined,
              border: canContinue ? "1px solid rgba(184,160,232,0.3)" : undefined,
              color: canContinue ? "var(--accent)" : undefined,
            }}>
              Extend 15 minutes
            </button>
          )}

          <button onClick={handleRematch} className="btn btn-ghost btn-md" style={{ width: "100%" }}>
            Back to lobby
          </button>
          <button onClick={handleSignOut} style={{
            padding: 13, background: "transparent", color: "var(--danger)",
            border: "none", fontFamily: "var(--font-ui)",
            fontSize: 13, fontWeight: 300, cursor: "pointer",
            textDecoration: "underline", textDecorationColor: "rgba(232,128,128,0.3)",
            textUnderlineOffset: "3px",
          }}>
            Sign out
          </button>
        </div>
      </div>
    </div>
  );
}

