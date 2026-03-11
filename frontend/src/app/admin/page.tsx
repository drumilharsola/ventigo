"use client";

import { useEffect, useState } from "react";
import { useAuthStore } from "@/store/authStore";
import { api } from "@/lib/api";

interface Stats {
  active_rooms: number;
  queued_users: number;
  board_requests: number;
  total_reports: number;
}

export default function AdminDashboard() {
  const { token } = useAuthStore();
  const [stats, setStats] = useState<Stats | null>(null);

  useEffect(() => {
    if (!token) return;
    api.adminStats(token).then(setStats).catch(() => {});
  }, [token]);

  if (!stats) return <p style={{ color: "var(--slate)" }}>Loading stats...</p>;

  const cards: { label: string; value: number; color: string }[] = [
    { label: "Active Rooms", value: stats.active_rooms, color: "var(--success)" },
    { label: "Queued Users", value: stats.queued_users, color: "var(--accent)" },
    { label: "Board Requests", value: stats.board_requests, color: "var(--flow-3)" },
    { label: "Reports", value: stats.total_reports, color: "var(--danger)" },
  ];

  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--ink)", marginBottom: 24 }}>
        Dashboard
      </h1>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 16 }}>
        {cards.map((c) => (
          <div
            key={c.label}
            style={{
              background: "white",
              borderRadius: "var(--r-lg)",
              padding: "20px 24px",
              boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
            }}
          >
            <div style={{ fontSize: 13, color: "var(--slate)", marginBottom: 8 }}>{c.label}</div>
            <div style={{ fontSize: 32, fontWeight: 700, color: c.color }}>{c.value}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
