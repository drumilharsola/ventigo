import type { Metadata } from "next";
import { Comfortaa, Inter } from "next/font/google";
import "./globals.css";
import { ThemeProvider } from "@/components/ThemeProvider";
import { brand } from "@/lib/brand";

const comfortaa = Comfortaa({
  variable: "--font-comfortaa",
  subsets: ["latin"],
  weight: ["400", "500", "700"],
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: `${brand.appName} - ${brand.tagline}`,
  description: `${brand.appName} yourself in 15 minutes. Anonymous, no pressure, just presence.`,
};

/* Inject brand theme colours as CSS custom-property overrides so clients
   can re-skin simply by editing brand.config.json. */
const brandCSS = `:root {
  --ink: ${brand.theme.ink};
  --charcoal: ${brand.theme.charcoal};
  --graphite: ${brand.theme.graphite};
  --slate: ${brand.theme.slate};
  --fog: ${brand.theme.fog};
  --mist: ${brand.theme.mist};
  --pale: ${brand.theme.pale};
  --snow: ${brand.theme.snow};
  --flow-1: ${brand.theme.flow1};
  --flow-2: ${brand.theme.flow2};
  --flow-3: ${brand.theme.flow3};
  --flow-4: ${brand.theme.flow4};
  --flow-5: ${brand.theme.flow5};
  --accent: ${brand.theme.accent};
  --accent-dim: ${brand.theme.accentDim};
  --accent-glow: ${brand.theme.accentGlow};
  --accent-hover: ${brand.theme.accentHover};
  --danger: ${brand.theme.danger};
  --success: ${brand.theme.success};
  --r-sm: ${brand.theme.radiusSm}px;
  --r-md: ${brand.theme.radiusMd}px;
  --r-lg: ${brand.theme.radiusLg}px;
  --r-xl: ${brand.theme.radiusXl}px;
  --r-full: ${brand.theme.radiusFull}px;
}`;

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <style dangerouslySetInnerHTML={{ __html: brandCSS }} />
      </head>
      <body className={`${comfortaa.variable} ${inter.variable} antialiased min-h-screen`}>
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
