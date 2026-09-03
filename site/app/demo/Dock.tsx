"use client";

import { AppIcon } from "./AppIcon";

/**
 * The Dock stays at the bottom of the page, as a Dock does. The AgentBar icon in its middle
 * opens the panel above it, as the app does; the other tiles are the page's sections, drawn
 * in one stroke, so the Dock is the page's second navigation.
 */
export function Dock({ open, onToggle }: { open: boolean; onToggle: () => void }) {
  return (
    <div className="dock" role="navigation" aria-label="The Dock">
      <Tile label="What it shows" href="#shows">
        <svg viewBox="0 0 64 64" aria-hidden="true">
          <rect x="6" y="6" width="52" height="52" rx="14" className="tile-ground tile-ground--blue" />
          <path d="M18 22h28M18 32h28M18 42h18" className="tile-line tile-line--light" />
          <rect x="18" y="20" width="9" height="4" rx="1" className="tile-fill tile-fill--green" />
          <rect x="18" y="30" width="19" height="4" rx="1" className="tile-fill tile-fill--amber" />
          <rect x="18" y="40" width="14" height="4" rx="1" className="tile-fill tile-fill--green" />
        </svg>
      </Tile>
      <Tile label="Where it lives" href="#lives">
        <svg viewBox="0 0 64 64" aria-hidden="true">
          <rect x="6" y="6" width="52" height="52" rx="14" className="tile-ground tile-ground--slate" />
          <rect x="14" y="16" width="36" height="6" rx="2" className="tile-fill tile-fill--light" />
          <rect x="30" y="26" width="20" height="14" rx="3" className="tile-fill tile-fill--light" opacity="0.85" />
          <rect x="16" y="44" width="32" height="6" rx="3" className="tile-fill tile-fill--light" opacity="0.6" />
        </svg>
      </Tile>
      <button
        type="button"
        className={`dock-tile dock-tile--app ${open ? "is-open" : ""}`}
        onClick={onToggle}
        aria-pressed={open}
        aria-label={open ? "Close the AgentBar panel" : "Open the AgentBar panel above the Dock"}
      >
        <span className="tile-label">AgentBar</span>
        <AppIcon size={52} />
        <i className="dock-running" aria-hidden="true" />
      </button>
      <Tile label="How it knows" href="#knows">
        <svg viewBox="0 0 64 64" aria-hidden="true">
          <rect x="6" y="6" width="52" height="52" rx="14" className="tile-ground tile-ground--ink" />
          <path d="M18 24l10 8-10 8" className="tile-line tile-line--light" />
          <path d="M32 40h14" className="tile-line tile-line--light" />
        </svg>
      </Tile>
      <Tile label="Download" href="#download">
        <svg viewBox="0 0 64 64" aria-hidden="true">
          <rect x="6" y="6" width="52" height="52" rx="14" className="tile-ground tile-ground--green" />
          <path d="M32 16v22M22 30l10 10 10-10M18 46h28" className="tile-line tile-line--light" />
        </svg>
      </Tile>
    </div>
  );
}

function Tile({ label, href, children }: { label: string; href: string; children: React.ReactNode }) {
  return (
    <a className="dock-tile" href={href} aria-label={label}>
      <span className="tile-label">{label}</span>
      {children}
    </a>
  );
}
