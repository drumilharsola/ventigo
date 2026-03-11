"use client";

import { useEffect, useState } from "react";
import { useAuthStore } from "@/store/authStore";
import { api } from "@/lib/api";

interface Report {
  report_id: string;
  reporter_session: string;
  reported_session: string;
  room_id: string;
  reason: string;
  detail: string;
  ts: string;
}

function fmtTime(ts: string) {
  if (!ts) return "";
  return new Date(Number(ts) * 1000).toLocaleString();
}

export default function AdminReports() {
  const { token } = useAuthStore();
  const [reports, setReports] = useState<Report[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [filterReason, setFilterReason] = useState("");
  const limit = 20;

  useEffect(() => {
    if (!token) return;
    api.adminListReports(token, offset, limit).then((d) => {
      setReports(d.reports as unknown as Report[]);
      setTotal(d.total);
    }).catch(() => {});
  }, [token, offset]);

  const filtered = filterReason
    ? reports.filter((r) => r.reason === filterReason)
    : reports;

  const reasons = ["harassment", "spam", "hate_speech", "inappropriate_content", "underage_suspected", "other"];

  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--ink)", marginBottom: 16 }}>
        Reports ({total})
      </h1>

      <div style={{ marginBottom: 16, display: "flex", gap: 8 }}>
        <select
          value={filterReason}
          onChange={(e) => setFilterReason(e.target.value)}
          style={{
            padding: "6px 12px",
            borderRadius: "var(--r-sm)",
            border: "1px solid var(--fog)",
            fontSize: 13,
          }}
        >
          <option value="">All reasons</option>
          {reasons.map((r) => (
            <option key={r} value={r}>{r}</option>
          ))}
        </select>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {filtered.map((r) => (
          <div
            key={r.report_id}
            style={{
              background: "white",
              borderRadius: "var(--r-md)",
              padding: "14px 18px",
              boxShadow: "0 1px 2px rgba(0,0,0,0.06)",
              cursor: "pointer",
            }}
            onClick={() => setExpanded(expanded === r.report_id ? null : r.report_id)}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
                <span
                  style={{
                    padding: "2px 8px",
                    borderRadius: "var(--r-sm)",
                    background: r.reason === "harassment" ? "var(--danger)" : "var(--slate)",
                    color: "white",
                    fontSize: 11,
                    fontWeight: 600,
                  }}
                >
                  {r.reason}
                </span>
                <span style={{ fontSize: 13, color: "var(--graphite)" }}>
                  Room: {r.room_id?.slice(0, 8)}...
                </span>
              </div>
              <span style={{ fontSize: 12, color: "var(--slate)" }}>{fmtTime(r.ts)}</span>
            </div>

            {expanded === r.report_id && (
              <div style={{ marginTop: 12, fontSize: 13, color: "var(--charcoal)" }}>
                <div><strong>Reporter:</strong> {r.reporter_session}</div>
                <div><strong>Reported:</strong> {r.reported_session}</div>
                <div><strong>Room:</strong> {r.room_id}</div>
                {r.detail && <div style={{ marginTop: 8 }}><strong>Detail:</strong> {r.detail}</div>}
              </div>
            )}
          </div>
        ))}
        {filtered.length === 0 && (
          <p style={{ color: "var(--slate)", fontSize: 14 }}>No reports found.</p>
        )}
      </div>

      {/* Pagination */}
      {total > limit && (
        <div style={{ display: "flex", gap: 8, marginTop: 16, justifyContent: "center" }}>
          <button
            disabled={offset === 0}
            onClick={() => setOffset(Math.max(0, offset - limit))}
            style={{ padding: "6px 14px", borderRadius: "var(--r-sm)", border: "1px solid var(--fog)", cursor: "pointer" }}
          >
            Previous
          </button>
          <span style={{ padding: "6px 0", fontSize: 13, color: "var(--slate)" }}>
            {offset + 1}-{Math.min(offset + limit, total)} of {total}
          </span>
          <button
            disabled={offset + limit >= total}
            onClick={() => setOffset(offset + limit)}
            style={{ padding: "6px 14px", borderRadius: "var(--r-sm)", border: "1px solid var(--fog)", cursor: "pointer" }}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}
