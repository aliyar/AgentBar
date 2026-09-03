"use client";

import { useEffect, useState } from "react";
import { Mark } from "./AppIcon";
import { level, limitsFor, short } from "./sample";

/**
 * The menu bar across the top of the desktop. The menus double as the page's sections;
 * the status item on the right is AgentBar's own, with the gauge on: Claude's three
 * windows as bars and the fullest one's time left, as the app shows by default.
 */
export function MenuBar({
  open,
  onToggle,
  theme,
  onTheme,
}: {
  open: boolean;
  onToggle: () => void;
  theme: "light" | "dark" | null;
  onTheme: () => void;
}) {
  const [clock, setClock] = useState("");
  useEffect(() => {
    const tick = () => {
      const d = new Date();
      setClock(`${d.toLocaleDateString("en-GB", { weekday: "short" })} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`);
    };
    tick();
    const id = window.setInterval(tick, 15_000);
    return () => window.clearInterval(id);
  }, []);

  return (
    <header className="menubar">
      <nav className="menubar-menus" aria-label="Sections">
        <span className="menubar-apple" aria-hidden="true">
          <svg viewBox="0 0 16 16" width="14" height="14" fill="currentColor">
            <path d="M11.2 8.5c0-1.4.8-2.2 1.7-2.8-.6-.9-1.6-1.5-2.7-1.5-1.1-.1-2.1.7-2.6.7-.6 0-1.4-.6-2.3-.6C3.9 4.4 2.5 5.7 2.5 8c0 1 .2 2 .6 3 .5 1.3 1.6 3.2 2.7 3.2.8 0 1.2-.6 2.3-.6s1.4.6 2.3.6c1.1 0 2.1-1.8 2.6-3.1-1.2-.6-1.8-1.5-1.8-2.6ZM9.6 3.3c.5-.6.8-1.4.7-2.2-.7.1-1.5.5-2 1.1-.5.5-.8 1.3-.7 2.1.8 0 1.5-.4 2-1Z" />
          </svg>
        </span>
        <span className="menubar-app">AgentBar</span>
        <a href="#shows">What it shows</a>
        <a href="#lives">Where it lives</a>
        <a href="#knows">How it knows</a>
        <a href="#faq">FAQ</a>
        <a href="#download" className="menubar-cta">Download</a>
      </nav>
      <div className="menubar-status">
        <StatusItem gauge open={open} onToggle={onToggle} id="agentbar-item" />
        <button type="button" className="mb-item mb-theme" onClick={onTheme} title={theme === "dark" ? "Switch to the light appearance" : "Switch to the dark appearance"} aria-label="Switch appearance">
          {theme === "dark" ? (
            <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" aria-hidden="true">
              <circle cx="8" cy="8" r="3" />
              <path d="M8 1.5v1.5M8 13v1.5M1.5 8H3M13 8h1.5M3.4 3.4l1 1M11.6 11.6l1 1M3.4 12.6l1-1M11.6 4.4l1-1" />
            </svg>
          ) : (
            <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
              <path d="M9.5 1.8a6.2 6.2 0 1 0 4.7 9.2 5 5 0 0 1-4.7-9.2Z" />
            </svg>
          )}
        </button>
        <span className="sys" aria-hidden="true">
          <svg viewBox="0 0 16 16" width="15" height="15" fill="currentColor"><path d="M8 12.6a1.3 1.3 0 1 1 0 2.6 1.3 1.3 0 0 1 0-2.6Zm0-3.4c1.3 0 2.5.5 3.4 1.3l-1.2 1.2a3.3 3.3 0 0 0-4.4 0L4.6 10.5A4.9 4.9 0 0 1 8 9.2Zm0-3.4c2.2 0 4.2.9 5.7 2.3l-1.2 1.2A6.4 6.4 0 0 0 8 7.5c-1.7 0-3.3.7-4.5 1.8L2.3 8.1A8 8 0 0 1 8 5.8Zm0-3.4c3.1 0 6 1.2 8 3.3l-1.2 1.2A9.6 9.6 0 0 0 8 4.1c-2.6 0-5 1-6.8 2.8L0 5.7a11.3 11.3 0 0 1 8-3.3Z" /></svg>
        </span>
        <span className="sys" aria-hidden="true">
          <svg viewBox="0 0 26 13" width="26" height="13" fill="none" stroke="currentColor"><rect x="1" y="1" width="21" height="11" rx="3" strokeOpacity="0.5" /><rect x="3" y="3" width="15" height="7" rx="1.5" fill="currentColor" stroke="none" /><path d="M24 4.5v4" strokeOpacity="0.5" strokeLinecap="round" /></svg>
        </span>
        <span className="menubar-clock">{clock || " "}</span>
      </div>
    </header>
  );
}

/** AgentBar's item: the mark alone, or the gauge (bars + the fullest window's time left). */
export function StatusItem({ gauge, open = false, onToggle, id }: { gauge: boolean; open?: boolean; onToggle?: () => void; id?: string }) {
  const claude = limitsFor("claude");
  const fullest = claude.reduce((a, b) => (b.percent > a.percent ? b : a));
  const lvl = level(fullest.percent);
  const label = gauge
    ? `AgentBar: ${claude.map((l) => `${l.title} ${Math.round(l.percent)}% used`).join(", ")}. ${short(fullest.resetsIn)} left on ${fullest.title}.`
    : "AgentBar";
  return (
    <button type="button" id={id} className={`mb-item ${open ? "is-open" : ""}`} onClick={onToggle} aria-expanded={onToggle ? open : undefined} aria-label={`${label} ${onToggle ? (open ? "Close the panel." : "Open the panel.") : ""}`.trim()}>
      {gauge ? (
        <>
          <span className="mb-bars" aria-hidden="true">
            {claude.map((l) => (
              <span key={l.id} className="mb-bar" style={{ ["--lit" as string]: `${Math.max(9, l.percent)}%`, ["--tint" as string]: `var(--${level(l.percent)})` }}>
                <i />
              </span>
            ))}
          </span>
          <span className="mb-time" style={{ color: `var(--${lvl})` }} aria-hidden="true">{short(fullest.resetsIn)}</span>
        </>
      ) : (
        <Mark size={16} className="mb-mark" />
      )}
    </button>
  );
}
