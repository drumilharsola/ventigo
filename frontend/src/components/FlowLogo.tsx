"use client";

import Link from "next/link";
import { brand } from "@/lib/brand";

interface FlowLogoProps {
  dark?: boolean;
  href?: string;
}

export function FlowLogo({ dark = false, href = "/" }: FlowLogoProps) {
  return (
    <Link
      href={href}
      style={{ display: "flex", alignItems: "center", gap: 10, textDecoration: "none" }}
    >
      <div style={{ position: "relative", width: 32, height: 32, flexShrink: 0 }}>
        {/* Spinning ring */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: "50%",
            border: `1.5px solid ${dark ? "rgba(184,160,232,0.7)" : "rgba(184,160,232,0.5)"}`,
            animation: "logo-spin 8s linear infinite",
          }}
        >
          {/* Orbiting dot */}
          <div
            style={{
              position: "absolute",
              width: 6,
              height: 6,
              background: "var(--accent)",
              borderRadius: "50%",
              top: -3,
              left: "50%",
              transform: "translateX(-50%)",
              boxShadow: "0 0 8px var(--accent)",
            }}
          />
        </div>
        {/* Core */}
        <div
          style={{
            position: "absolute",
            top: 7,
            right: 7,
            bottom: 7,
            left: 7,
            borderRadius: "50%",
            background: "var(--accent)",
            opacity: 0.6,
          }}
        />
      </div>
      <span
        style={{
          fontFamily: "var(--font-display)",
          fontWeight: 700,
          fontSize: 20,
          letterSpacing: "-0.02em",
          color: dark ? "var(--ink)" : "var(--white)",
        }}
      >
        {brand.logo.prefix}<em style={{ fontStyle: "italic", color: "var(--accent)" }}>{brand.logo.emphasis}</em>{brand.logo.suffix}
      </span>
    </Link>
  );
}
