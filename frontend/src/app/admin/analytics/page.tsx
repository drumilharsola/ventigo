"use client";

import { useEffect, useState, useCallback } from "react";
import { useAuthStore } from "@/store/authStore";
import { api } from "@/lib/api";

type Overview = {
  dau: number;
  mau: number;
  sessions_today: number;
  registrations_today: number;
  reports_today: number;
  board_posts_today: number;
  avg_session_duration: number;
};

type TimeseriesPoint = { date: string; value: number };

const METRICS = [
  { key: "dau", label: "Daily Active Users" },
  { key: "sessions", label: "Sessions" },
  { key: "registrations", label: "Registrations" },
  { key: "reports", label: "Reports" },
  { key: "board_posts", label: "Board Posts" },
];

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}m ${s}s`;
}

function MiniChart({ data }: { data: TimeseriesPoint[] }) {
  if (!data.length) return <p style={{ color: "var(--slate)", fontSize: 13 }}>No data</p>;
  const values = data.map((d) => d.value);
  const max = Math.max(...values, 1);
  const w = 480;
  const h = 120;
  const pad = 4;

  const points = data
    .map((d, i) => {
      const x = pad + (i / Math.max(data.length - 1, 1)) * (w - 2 * pad);
      const y = h - pad - (d.value / max) * (h - 2 * pad);
      return `${x},${y}`;
    })
    .join(" ");

  return (
    <svg viewBox={`0 0 ${w} ${h}`} style={{ width: "100%", maxWidth: w, height: "auto" }}>
      <polyline
        fill="none"
        stroke="var(--accent)"
        strokeWidth={2}
        points={points}
      />
      {data.map((d, i) => {
        const x = pad + (i / Math.max(data.length - 1, 1)) * (w - 2 * pad);
        const y = h - pad - (d.value / max) * (h - 2 * pad);
        return <circle key={i} cx={x} cy={y} r={3} fill="var(--accent)" />;
      })}
    </svg>
  );
}

export default function AnalyticsPage() {
  const { token } = useAuthStore();
  const [overview, setOverview] = useState<Overview | null>(null);
  const [metric, setMetric] = useState("dau");
  const [tsData, setTsData] = useState<TimeseriesPoint[]>([]);
  const [days, setDays] = useState(30);

  const loadOverview = useCallback(async () => {
    if (!token) return;
    try {
      const data = await api.adminAnalyticsOverview(token);
      setOverview(data);
    } catch {
      /* admin auth failure handled by layout */
    }
  }, [token]);

  const loadTimeseries = useCallback(async () => {
    if (!token) return;
    const to = new Date();
    const from = new Date(to);
    from.setDate(from.getDate() - (days - 1));
    const fmt = (d: Date) => d.toISOString().slice(0, 10);
    try {
      const res = await api.adminAnalyticsTimeseries(token, metric, fmt(from), fmt(to));
      setTsData(res.data);
    } catch {
      /* handled */
    }
  }, [token, metric, days]);

  useEffect(() => {
    loadOverview();
  }, [loadOverview]);

  useEffect(() => {
    loadTimeseries();
  }, [loadTimeseries]);

  const cardStyle: React.CSSProperties = {
    background: "white",
    borderRadius: 12,
    padding: "20px 24px",
    boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
    textAlign: "center" as const,
  };

  const labelStyle: React.CSSProperties = {
    fontSize: 12,
    color: "var(--slate)",
    marginBottom: 4,
    textTransform: "uppercase" as const,
    letterSpacing: 0.5,
  };

  const valueStyle: React.CSSProperties = {
    fontSize: 28,
    fontWeight: 700,
    color: "var(--ink)",
  };

  return (
    <div>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 24, color: "var(--ink)" }}>
        Analytics
      </h1>

      {/* Overview cards */}
      {overview && (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))",
            gap: 16,
            marginBottom: 32,
          }}
        >
          <div style={cardStyle}>
            <div style={labelStyle}>DAU</div>
            <div style={valueStyle}>{overview.dau}</div>
          </div>
          <div style={cardStyle}>
            <div style={labelStyle}>MAU</div>
            <div style={valueStyle}>{overview.mau}</div>
          </div>
          <div style={cardStyle}>
            <div style={labelStyle}>Sessions</div>
            <div style={valueStyle}>{overview.sessions_today}</div>
          </div>
          <div style={cardStyle}>
            <div style={labelStyle}>Registrations</div>
            <div style={valueStyle}>{overview.registrations_today}</div>
          </div>
          <div style={cardStyle}>
            <div style={labelStyle}>Reports</div>
            <div style={valueStyle}>{overview.reports_today}</div>
          </div>
          <div style={cardStyle}>
            <div style={labelStyle}>Board Posts</div>
            <div style={valueStyle}>{overview.board_posts_today}</div>
          </div>
          <div style={cardStyle}>
            <div style={labelStyle}>Avg Duration</div>
            <div style={valueStyle}>{formatDuration(overview.avg_session_duration)}</div>
          </div>
        </div>
      )}

      {/* Timeseries chart */}
      <div style={{ background: "white", borderRadius: 12, padding: 24, boxShadow: "0 1px 3px rgba(0,0,0,0.08)" }}>
        <div style={{ display: "flex", gap: 12, alignItems: "center", marginBottom: 16, flexWrap: "wrap" }}>
          <select
            value={metric}
            onChange={(e) => setMetric(e.target.value)}
            style={{
              padding: "6px 12px",
              borderRadius: 8,
              border: "1px solid var(--fog)",
              fontSize: 14,
              background: "white",
            }}
          >
            {METRICS.map((m) => (
              <option key={m.key} value={m.key}>{m.label}</option>
            ))}
          </select>
          <select
            value={days}
            onChange={(e) => setDays(Number(e.target.value))}
            style={{
              padding: "6px 12px",
              borderRadius: 8,
              border: "1px solid var(--fog)",
              fontSize: 14,
              background: "white",
            }}
          >
            <option value={7}>Last 7 days</option>
            <option value={14}>Last 14 days</option>
            <option value={30}>Last 30 days</option>
            <option value={60}>Last 60 days</option>
            <option value={90}>Last 90 days</option>
          </select>
        </div>
        <MiniChart data={tsData} />
        {tsData.length > 0 && (
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              fontSize: 11,
              color: "var(--slate)",
              marginTop: 4,
              padding: "0 4px",
            }}
          >
            <span>{tsData[0].date}</span>
            <span>{tsData[tsData.length - 1].date}</span>
          </div>
        )}
      </div>
    </div>
  );
}
