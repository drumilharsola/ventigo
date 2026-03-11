"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { useAuthStore } from "@/store/authStore";
import { api } from "@/lib/api";
import { brand } from "@/lib/brand";

const NAV_ITEMS = [
  { href: "/admin", label: "Dashboard" },
  { href: "/admin/analytics", label: "Analytics" },
  { href: "/admin/reports", label: "Reports" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/tenants", label: "Tenants" },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const { token, _hasHydrated } = useAuthStore();
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);

  useEffect(() => {
    if (!_hasHydrated) return;
    if (!token) {
      router.push("/verify");
      return;
    }
    // Check admin access by hitting a protected endpoint
    api.adminStats(token)
      .then(() => setIsAdmin(true))
      .catch(() => {
        setIsAdmin(false);
        router.push("/lobby");
      });
  }, [_hasHydrated, token, router]);

  if (!_hasHydrated || isAdmin === null) {
    return (
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100vh" }}>
        <p style={{ color: "var(--slate)" }}>Loading...</p>
      </div>
    );
  }

  if (!isAdmin) return null;

  return (
    <div style={{ display: "flex", minHeight: "100vh", background: "var(--snow)" }}>
      {/* Sidebar */}
      <nav
        style={{
          width: 220,
          background: "var(--ink)",
          color: "var(--snow)",
          padding: "24px 0",
          display: "flex",
          flexDirection: "column",
          gap: 4,
          flexShrink: 0,
        }}
      >
        <div style={{ padding: "0 20px 20px", fontFamily: "var(--font-comfortaa)", fontWeight: 700, fontSize: 18 }}>
          {brand.appName} Admin
        </div>
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              style={{
                padding: "10px 20px",
                color: active ? "var(--accent)" : "var(--fog)",
                textDecoration: "none",
                fontSize: 14,
                fontWeight: active ? 600 : 400,
                background: active ? "rgba(255,255,255,0.05)" : "transparent",
                borderLeft: active ? "3px solid var(--accent)" : "3px solid transparent",
              }}
            >
              {item.label}
            </Link>
          );
        })}
        <div style={{ flex: 1 }} />
        <Link
          href="/lobby"
          style={{ padding: "10px 20px", color: "var(--slate)", textDecoration: "none", fontSize: 13 }}
        >
          &larr; Back to app
        </Link>
      </nav>

      {/* Main content */}
      <main style={{ flex: 1, padding: 32, overflowY: "auto" }}>{children}</main>
    </div>
  );
}
