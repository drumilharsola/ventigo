import brandConfig from "../../../brand.config.json";

// ── Types ────────────────────────────────────────────────────────────────────

export interface BrandLogo {
  text: string;
  prefix: string;
  emphasis: string;
  suffix: string;
}

export interface BrandTheme {
  ink: string;
  ink80: string;
  charcoal: string;
  graphite: string;
  slate: string;
  fog: string;
  mist: string;
  pale: string;
  snow: string;
  white: string;
  flow1: string;
  flow2: string;
  flow3: string;
  flow4: string;
  flow5: string;
  accent: string;
  accentDim: string;
  accentGlow: string;
  accentHover: string;
  danger: string;
  success: string;
  card: string;
  cardLight: string;
  border: string;
  borderLight: string;
  fontDisplay: string;
  fontUI: string;
  radiusSm: number;
  radiusMd: number;
  radiusLg: number;
  radiusXl: number;
  radiusFull: number;
}

export interface BrandConfig {
  appName: string;
  appNamePlain: string;
  tagline: string;
  description: string;
  supportEmail: string;
  senderName: string;
  senderEmail: string;
  logo: BrandLogo;
  theme: BrandTheme;
}

// ── Export ────────────────────────────────────────────────────────────────────

export const brand: BrandConfig = brandConfig as BrandConfig;
