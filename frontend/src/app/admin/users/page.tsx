"use client";

import { useState } from "react";
import { useAuthStore } from "@/store/authStore";
import { api } from "@/lib/api";

interface UserProfile {
  username: string;
  avatar_id: string;
  speak_count: string;
  listen_count: string;
  created_at: string;
  email_verified: string;
  suspended: string;
  is_admin: string;
  session_id: string;
  report_count: number;
}

function fmtDate(ts: string) {
  if (!ts || ts === "0") return "N/A";
  return new Date(Number(ts) * 1000).toLocaleDateString();
}

export default function AdminUsers() {
  const { token } = useAuthStore();
  const [searchId, setSearchId] = useState("");
  const [user, setUser] = useState<UserProfile | null>(null);
  const [error, setError] = useState("");
  const [actionLoading, setActionLoading] = useState(false);

  const search = async () => {
    if (!token || !searchId.trim()) return;
    setError("");
    setUser(null);
    try {
      const data = await api.adminGetUser(token, searchId.trim());
      setUser(data as unknown as UserProfile);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "User not found");
    }
  };

  const toggleSuspend = async () => {
    if (!token || !user) return;
    setActionLoading(true);
    try {
      if (user.suspended === "1") {
        await api.adminUnsuspendUser(token, user.session_id);
        setUser({ ...user, suspended: "0" });
      } else {
        await api.adminSuspendUser(token, user.session_id);
        setUser({ ...user, suspended: "1" });
      }
    } catch {
      /* ignore */
    }
    setActionLoading(false);
  };

  const toggleAdmin = async () => {
    if (!token || !user) return;
    setActionLoading(true);
    try {
      if (user.is_admin === "1") {
        await api.adminRevokeModerator(token, user.session_id);
        setUser({ ...user, is_admin: "0" });
      } else {
        await api.adminGrantModerator(token, user.session_id);
        setUser({ ...user, is_admin: "1" });
      }
    } catch {
      /* ignore */
    }
    setActionLoading(false);
  };

  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--ink)", marginBottom: 16 }}>
        User Management
      </h1>

      <div style={{ display: "flex", gap: 8, marginBottom: 24 }}>
        <input
          value={searchId}
          onChange={(e) => setSearchId(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && search()}
          placeholder="Enter session ID..."
          style={{
            flex: 1,
            maxWidth: 400,
            padding: "8px 14px",
            borderRadius: "var(--r-sm)",
            border: "1px solid var(--fog)",
            fontSize: 14,
          }}
        />
        <button
          onClick={search}
          style={{
            padding: "8px 20px",
            borderRadius: "var(--r-sm)",
            background: "var(--accent)",
            color: "white",
            border: "none",
            cursor: "pointer",
            fontWeight: 600,
            fontSize: 14,
          }}
        >
          Search
        </button>
      </div>

      {error && <p style={{ color: "var(--danger)", fontSize: 14, marginBottom: 16 }}>{error}</p>}

      {user && (
        <div style={{
          background: "white",
          borderRadius: "var(--r-lg)",
          padding: 24,
          boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
          maxWidth: 500,
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h2 style={{ fontSize: 18, fontWeight: 700, color: "var(--ink)" }}>
              {user.username || "No profile"}
            </h2>
            <div style={{ display: "flex", gap: 4 }}>
              {user.suspended === "1" && (
                <span style={{ padding: "2px 8px", borderRadius: "var(--r-sm)", background: "var(--danger)", color: "white", fontSize: 11 }}>
                  SUSPENDED
                </span>
              )}
              {user.is_admin === "1" && (
                <span style={{ padding: "2px 8px", borderRadius: "var(--r-sm)", background: "var(--accent)", color: "white", fontSize: 11 }}>
                  ADMIN
                </span>
              )}
            </div>
          </div>

          <div style={{ fontSize: 13, color: "var(--charcoal)", display: "flex", flexDirection: "column", gap: 6 }}>
            <div><strong>Session ID:</strong> {user.session_id}</div>
            <div><strong>Speak count:</strong> {user.speak_count || 0}</div>
            <div><strong>Listen count:</strong> {user.listen_count || 0}</div>
            <div><strong>Email verified:</strong> {user.email_verified === "1" ? "Yes" : "No"}</div>
            <div><strong>Created:</strong> {fmtDate(user.created_at)}</div>
            <div>
              <strong>Reports against:</strong>{" "}
              <span style={{ color: user.report_count > 0 ? "var(--danger)" : "var(--slate)" }}>
                {user.report_count}
              </span>
            </div>
          </div>

          <div style={{ display: "flex", gap: 8, marginTop: 20 }}>
            <button
              onClick={toggleSuspend}
              disabled={actionLoading}
              style={{
                padding: "8px 16px",
                borderRadius: "var(--r-sm)",
                background: user.suspended === "1" ? "var(--success)" : "var(--danger)",
                color: "white",
                border: "none",
                cursor: "pointer",
                fontSize: 13,
                fontWeight: 600,
              }}
            >
              {user.suspended === "1" ? "Unsuspend" : "Suspend"}
            </button>
            <button
              onClick={toggleAdmin}
              disabled={actionLoading}
              style={{
                padding: "8px 16px",
                borderRadius: "var(--r-sm)",
                background: user.is_admin === "1" ? "var(--slate)" : "var(--accent)",
                color: "white",
                border: "none",
                cursor: "pointer",
                fontSize: 13,
                fontWeight: 600,
              }}
            >
              {user.is_admin === "1" ? "Revoke Admin" : "Grant Admin"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
