import { cn } from "@/lib/utils";

interface BrandMarkProps {
  className?: string;
  /** White nodes on primary tile (default) or primary nodes on transparent */
  variant?: "tile" | "mono";
}

/**
 * Nexus AI mark: interconnected neural / relationship nodes and graph links.
 */
export function BrandMark({ className, variant = "tile" }: BrandMarkProps) {
  const nodeFill = variant === "tile" ? "#FFFFFF" : "currentColor";
  const lineStroke = variant === "tile" ? "#FFFFFF" : "currentColor";
  const hubOpacity = variant === "tile" ? 1 : 0.9;

  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={cn("shrink-0", className)}
      aria-label="Nexus AI"
      role="img"
    >
      {variant === "tile" && (
        <rect width="32" height="32" rx="8" className="fill-primary" />
      )}
      {/* Warm intro path: you ↔ mutual ↔ contact */}
      <path
        d="M9 17.5C9 17.5 12.5 11.5 16 11.5C19.5 11.5 23 17.5 23 17.5"
        stroke={lineStroke}
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
        opacity={hubOpacity}
      />
      <line
        x1="9"
        y1="17.5"
        x2="12.25"
        y2="14.75"
        stroke={lineStroke}
        strokeWidth="1.75"
        strokeLinecap="round"
        opacity={0.7}
      />
      <line
        x1="23"
        y1="17.5"
        x2="19.75"
        y2="14.75"
        stroke={lineStroke}
        strokeWidth="1.75"
        strokeLinecap="round"
        opacity={0.7}
      />
      {/* Mutual connection (top) */}
      <circle cx="16" cy="10.5" r="2.75" fill={nodeFill} opacity={hubOpacity} />
      {/* You (left) */}
      <circle cx="8.5" cy="18.5" r="3.25" fill={nodeFill} />
      {/* Contact (right) */}
      <circle cx="23.5" cy="18.5" r="3.25" fill={nodeFill} />
      {/* Center pulse: relationship hub */}
      <circle cx="16" cy="15" r="1.25" fill={nodeFill} opacity={0.5} />
    </svg>
  );
}

/** Inline SVG string for email templates (Indigo tile, 44px). */
export const EMAIL_LOGO_MARK_SVG = `<svg width="44" height="44" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Nexus AI">
  <rect width="32" height="32" rx="8" fill="#4F46E5"/>
  <path d="M9 17.5C9 17.5 12.5 11.5 16 11.5C19.5 11.5 23 17.5 23 17.5" stroke="#FFFFFF" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
  <line x1="9" y1="17.5" x2="12.25" y2="14.75" stroke="#FFFFFF" stroke-width="1.75" stroke-linecap="round" opacity="0.7"/>
  <line x1="23" y1="17.5" x2="19.75" y2="14.75" stroke="#FFFFFF" stroke-width="1.75" stroke-linecap="round" opacity="0.7"/>
  <circle cx="16" cy="10.5" r="2.75" fill="#FFFFFF"/>
  <circle cx="8.5" cy="18.5" r="3.25" fill="#FFFFFF"/>
  <circle cx="23.5" cy="18.5" r="3.25" fill="#FFFFFF"/>
  <circle cx="16" cy="15" r="1.25" fill="#FFFFFF" opacity="0.5"/>
</svg>`;
