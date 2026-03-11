"use client";

import { useEffect, useState } from "react";
import { useAuthStore } from "@/store/authStore";
import { api } from "@/lib/api";

interface Tenant {
  tenant_id: string;
  name: string;
  domain: string;
  active: boolean;
  created_at: number;
  config: Record<string, unknown>;
}

export default function AdminTenants() {
  const { token } = useAuthStore();
  const [adminKey, setAdminKey] = useState("");
  const [unlocked, setUnlocked] = useState(false);
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [error, setError] = useState("");

  // Create form
  const [newId, setNewId] = useState("");
  const [newName, setNewName] = useState("");
  const [newDomain, setNewDomain] = useState("");
  const [creating, setCreating] = useState(false);

  const unlock = async () => {
    if (!adminKey.trim()) return;
    setError("");
    try {
      const data = await api.adminListTenants(adminKey);
      setTenants(data.tenants as unknown as Tenant[]);
      setUnlocked(true);
    } catch {
      setError("Invalid admin key");
    }
  };

  const refresh = async () => {
    try {
      const data = await api.adminListTenants(adminKey);
      setTenants(data.tenants as unknown as Tenant[]);
    } catch { /* ignore */ }
  };

  const createTenant = async () => {
    if (!newId.trim() || !newName.trim()) return;
    setCreating(true);
    setError("");
    try {
      await api.adminCreateTenant(adminKey, {
        tenant_id: newId.trim(),
        name: newName.trim(),
        domain: newDomain.trim() || undefined,
      });
      setNewId("");
      setNewName("");
      setNewDomain("");
      await refresh();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to create tenant");
    }
    setCreating(false);
  };

  const toggleActive = async (t: Tenant) => {
    try {
      await api.adminUpdateTenant(adminKey, t.tenant_id, { active: !t.active });
      await refresh();
    } catch { /* ignore */ }
  };

  if (!unlocked) {
    return (
      <div>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--ink)", marginBottom: 16 }}>
          Tenant Management
        </h1>
        <p style={{ color: "var(--slate)", fontSize: 14, marginBottom: 16 }}>
          Enter the admin API key to manage tenants.
        </p>
        <div style={{ display: "flex", gap: 8 }}>
          <input
            type="password"
            value={adminKey}
            onChange={(e) => setAdminKey(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && unlock()}
            placeholder="Admin API Key"
            style={{
              flex: 1, maxWidth: 300, padding: "8px 14px",
              borderRadius: "var(--r-sm)", border: "1px solid var(--fog)", fontSize: 14,
            }}
          />
          <button
            onClick={unlock}
            style={{
              padding: "8px 20px", borderRadius: "var(--r-sm)", background: "var(--accent)",
              color: "white", border: "none", cursor: "pointer", fontWeight: 600,
            }}
          >
            Unlock
          </button>
        </div>
        {error && <p style={{ color: "var(--danger)", fontSize: 13, marginTop: 8 }}>{error}</p>}
      </div>
    );
  }

  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, color: "var(--ink)", marginBottom: 16 }}>
        Tenant Management
      </h1>

      {/* Create form */}
      <div style={{
        background: "white", borderRadius: "var(--r-lg)", padding: 20,
        boxShadow: "0 1px 3px rgba(0,0,0,0.08)", marginBottom: 24,
      }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, color: "var(--charcoal)", marginBottom: 12 }}>
          Create Tenant
        </h2>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input
            value={newId} onChange={(e) => setNewId(e.target.value)} placeholder="tenant_id"
            style={{ padding: "8px 12px", borderRadius: "var(--r-sm)", border: "1px solid var(--fog)", fontSize: 13, width: 150 }}
          />
          <input
            value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="Display name"
            style={{ padding: "8px 12px", borderRadius: "var(--r-sm)", border: "1px solid var(--fog)", fontSize: 13, width: 200 }}
          />
          <input
            value={newDomain} onChange={(e) => setNewDomain(e.target.value)} placeholder="Domain (optional)"
            style={{ padding: "8px 12px", borderRadius: "var(--r-sm)", border: "1px solid var(--fog)", fontSize: 13, width: 200 }}
          />
          <button
            onClick={createTenant} disabled={creating}
            style={{
              padding: "8px 16px", borderRadius: "var(--r-sm)", background: "var(--success)",
              color: "white", border: "none", cursor: "pointer", fontWeight: 600, fontSize: 13,
            }}
          >
            {creating ? "Creating..." : "Create"}
          </button>
        </div>
        {error && <p style={{ color: "var(--danger)", fontSize: 13, marginTop: 8 }}>{error}</p>}
      </div>

      {/* Tenant list */}
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {tenants.map((t) => (
          <div
            key={t.tenant_id}
            style={{
              background: "white", borderRadius: "var(--r-md)", padding: "14px 18px",
              boxShadow: "0 1px 2px rgba(0,0,0,0.06)",
              display: "flex", justifyContent: "space-between", alignItems: "center",
              opacity: t.active ? 1 : 0.5,
            }}
          >
            <div>
              <div style={{ fontWeight: 600, color: "var(--ink)", fontSize: 15 }}>{t.name}</div>
              <div style={{ fontSize: 12, color: "var(--slate)" }}>
                ID: {t.tenant_id}{t.domain ? ` | ${t.domain}` : ""}
              </div>
            </div>
            <button
              onClick={() => toggleActive(t)}
              style={{
                padding: "4px 12px", borderRadius: "var(--r-sm)", fontSize: 12, fontWeight: 600,
                background: t.active ? "var(--danger)" : "var(--success)",
                color: "white", border: "none", cursor: "pointer",
              }}
            >
              {t.active ? "Disable" : "Enable"}
            </button>
          </div>
        ))}
        {tenants.length === 0 && (
          <p style={{ color: "var(--slate)", fontSize: 14 }}>No tenants found.</p>
        )}
      </div>
    </div>
  );
}
