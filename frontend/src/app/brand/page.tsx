"use client";

import { FlowLogo } from "@/components/FlowLogo";

const COLORS = [
  { name: "--ink", value: "#0d0d0f", label: "Ink" },
  { name: "--charcoal", value: "#1a1a1f", label: "Charcoal" },
  { name: "--graphite", value: "#2c2c35", label: "Graphite" },
  { name: "--slate", value: "#6b6b80", label: "Slate" },
  { name: "--fog", value: "#a8a8bf", label: "Fog" },
  { name: "--mist", value: "#c8c8d9", label: "Mist" },
  { name: "--pale", value: "#e4e4f0", label: "Pale" },
  { name: "--snow", value: "#f8f7f5", label: "Snow" },
  { name: "--white", value: "#ffffff", label: "White" },
];

const ACCENTS = [
  { name: "--flow-1", value: "#f0eaff", label: "Flow 1" },
  { name: "--flow-2", value: "#d4bff7", label: "Flow 2" },
  { name: "--flow-3", value: "#b8a0e8", label: "Flow 3 / Accent" },
  { name: "--flow-4", value: "#9070cc", label: "Flow 4" },
  { name: "--flow-5", value: "#6040a8", label: "Flow 5" },
  { name: "--danger", value: "#e88080", label: "Danger" },
  { name: "--success", value: "#80c8a0", label: "Success" },
];

const RADII = [
  { name: "--r-sm", value: "10px", label: "sm · 10px" },
  { name: "--r-md", value: "18px", label: "md · 18px" },
  { name: "--r-lg", value: "28px", label: "lg · 28px" },
  { name: "--r-xl", value: "40px", label: "xl · 40px" },
  { name: "--r-full", value: "999px", label: "full · 999px" },
];

function Swatch({ color, label, name }: { color: string; label: string; name: string }) {
  const isDark = ["#0d0d0f","#1a1a1f","#2c2c35","#6b6b80","#9070cc","#6040a8","#e88080","#a8a8bf"].includes(color);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      <div style={{
        height: 72, borderRadius: "var(--r-md)",
        background: color,
        border: "1px solid rgba(0,0,0,0.08)",
      }} />
      <p style={{ margin: 0, fontSize: 12, fontWeight: 600, color: isDark ? "var(--ink)" : "var(--charcoal)", fontFamily: "var(--font-ui)" }}>{label}</p>
      <p style={{ margin: 0, fontSize: 10, color: "var(--slate)", fontFamily: "var(--font-ui)" }}>{name}<br />{color}</p>
    </div>
  );
}

export default function BrandPage() {
  return (
    <div className="light-canvas" style={{ minHeight: "100vh", padding: "32px" }}>
      {/* Nav */}
      <nav style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        marginBottom: 56, paddingBottom: 20,
        borderBottom: "1px solid rgba(0,0,0,0.08)",
      }}>
        <FlowLogo dark />
        <span className="pill" style={{ fontSize: 10 }}>Brand Tokens · Internal</span>
      </nav>

      <div style={{ maxWidth: 960, margin: "0 auto", display: "flex", flexDirection: "column", gap: 60 }}>

        {/* Typography */}
        <section>
          <h2 style={{ fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--slate)", marginBottom: 24 }}>Typography</h2>
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <p style={{ fontFamily: "var(--font-display)", fontSize: 72, fontWeight: 900, color: "var(--ink)", letterSpacing: "-0.04em", margin: 0, lineHeight: 1 }}>Flow.</p>
            <p style={{ fontFamily: "var(--font-display)", fontSize: 48, fontWeight: 700, fontStyle: "italic", color: "var(--ink)", letterSpacing: "-0.03em", margin: 0 }}>Let it <em style={{ color: "var(--accent)" }}>out.</em></p>
            <p style={{ fontFamily: "var(--font-display)", fontSize: 28, fontWeight: 400, color: "var(--charcoal)", margin: 0 }}>A safe place to be heard.</p>
            <p style={{ fontFamily: "var(--font-ui)", fontSize: 16, fontWeight: 300, color: "var(--slate)", margin: 0, maxWidth: 500 }}>Syne is used for UI text - labels, buttons, body copy at small sizes. Clean, geometric, and unobtrusive.</p>
            <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
              <span className="pill pill-accent">pill · accent</span>
              <span className="pill pill-success">pill · success</span>
              <span className="pill">pill · default</span>
            </div>
          </div>
        </section>

        {/* Neutrals */}
        <section>
          <h2 style={{ fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--slate)", marginBottom: 24 }}>Neutrals</h2>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(90px, 1fr))", gap: 16 }}>
            {COLORS.map((c) => <Swatch key={c.name} color={c.value} label={c.label} name={c.name} />)}
          </div>
        </section>

        {/* Accent palette */}
        <section>
          <h2 style={{ fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--slate)", marginBottom: 24 }}>Accent Palette</h2>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(90px, 1fr))", gap: 16 }}>
            {ACCENTS.map((c) => <Swatch key={c.name} color={c.value} label={c.label} name={c.name} />)}
          </div>
        </section>

        {/* Radius */}
        <section>
          <h2 style={{ fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--slate)", marginBottom: 24 }}>Border Radius</h2>
          <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "flex-end" }}>
            {RADII.map((r) => (
              <div key={r.name} style={{ display: "flex", flexDirection: "column", gap: 8, alignItems: "center" }}>
                <div style={{
                  width: 64, height: 64,
                  background: "var(--flow-3)",
                  borderRadius: r.value,
                  opacity: 0.6,
                }} />
                <p style={{ margin: 0, fontSize: 10, color: "var(--slate)", fontFamily: "var(--font-ui)", textAlign: "center" }}>{r.label}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Buttons */}
        <section>
          <h2 style={{ fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--slate)", marginBottom: 24 }}>Buttons</h2>
          <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center" }}>
            <button className="btn btn-primary btn-lg">Primary LG</button>
            <button className="btn btn-accent btn-lg">Accent LG</button>
            <button className="btn btn-primary btn-md">Primary MD</button>
            <button className="btn btn-accent btn-md">Accent MD</button>
            <button className="btn btn-ghost btn-md">Ghost MD</button>
            <button className="btn btn-danger btn-sm">Danger SM</button>
          </div>
        </section>

        {/* Dark buttons */}
        <section style={{ background: "var(--ink)", borderRadius: "var(--r-lg)", padding: 32 }}>
          <h2 style={{ fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--slate)", marginBottom: 24 }}>On Dark Canvas</h2>
          <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center" }}>
            <button className="btn btn-accent btn-lg">Accent LG</button>
            <button className="btn btn-ghost-dark btn-md">Ghost Dark</button>
            <div className="glass-card" style={{ padding: "16px 20px", display: "inline-flex", alignItems: "center", gap: 10 }}>
              <span style={{ fontSize: 13, color: "var(--fog)", fontFamily: "var(--font-ui)" }}>Glass card component</span>
            </div>
          </div>
        </section>

        <footer style={{ paddingTop: 24, borderTop: "1px solid rgba(0,0,0,0.08)" }}>
          <p style={{ fontSize: 11, color: "var(--mist)", fontFamily: "var(--font-ui)" }}>
            Ventigo Brand System · Internal reference only
          </p>
        </footer>
      </div>
    </div>
  );
}
