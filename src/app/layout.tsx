import type { Metadata, Viewport } from "next";
import Script from "next/script";
import { Inter, Plus_Jakarta_Sans, Geist_Mono } from "next/font/google";
import { Providers } from "@/components/providers";
import { SplashStatic } from "@/components/pwa/splash-static";
import { SPLASH_BOOTSTRAP_SCRIPT } from "@/components/pwa/splash-bootstrap";
import "./globals.css";

const inter = Inter({
  variable: "--font-sans",
  subsets: ["latin"],
  display: "swap",
});

const plusJakartaSans = Plus_Jakarta_Sans({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["500", "600", "700", "800"],
  display: "swap",
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Nexus AI | Relationship Intelligence Platform",
  description:
    "Next-generation relationship intelligence for warm introductions, network mapping, and automated pipeline workflows.",
  applicationName: "Nexus AI",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Nexus AI",
  },
  formatDetection: {
    telephone: false,
  },
  icons: {
    icon: [{ url: "/icon.svg", type: "image/svg+xml" }],
    apple: [{ url: "/apple-icon", sizes: "180x180", type: "image/png" }],
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#4f46e5" },
    { media: "(prefers-color-scheme: dark)", color: "#090d16" },
  ],
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${plusJakartaSans.variable} ${geistMono.variable}`}
      suppressHydrationWarning
    >
      <body className={`${inter.className} antialiased`} suppressHydrationWarning>
        <Script
          id="nexus-splash-bootstrap"
          strategy="beforeInteractive"
          dangerouslySetInnerHTML={{ __html: SPLASH_BOOTSTRAP_SCRIPT }}
        />
        <SplashStatic />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
