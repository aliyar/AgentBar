"use client";

import { useEffect, useRef, useState } from "react";
import { Mark } from "./AppIcon";
import { Dock } from "./Dock";
import { MenuBar } from "./MenuBar";
import { Panel } from "./Panel";
import { TerminalPanel } from "./TerminalPanel";
import { usePanelState } from "./state";
import { release } from "../release";
import { site } from "../site";

/**
 * The first viewport: a Mac desktop with AgentBar living on it everywhere at once. The
 * menu bar item opens the panel beneath it; the Dock icon opens the same panel above the
 * Dock; the words and the download sit on the desktop itself.
 */
export function Desktop() {
  // Open on arrival where there is room beside the words; closed on a phone or a narrow
  // window, where it would cover them - a click on the item opens it there.
  const [menuOpen, setMenuOpen] = useState(false);
  useEffect(() => {
    if (window.matchMedia("(min-width: 900px)").matches) setMenuOpen(true);
  }, []);
  const [dockOpen, setDockOpen] = useState(false);
  const [style, setStyle] = useState<"glass" | "terminal">("glass");
  const [theme, setTheme] = useState<"light" | "dark" | null>(null);
  const state = usePanelState();
  const stageRef = useRef<HTMLDivElement>(null);
  /** Where the panel's arrow goes: under the centre of the status item, measured. */
  const [arrowRight, setArrowRight] = useState<number | null>(null);
  useEffect(() => {
    const measure = () => {
      const item = document.getElementById("agentbar-item");
      const host = document.querySelector<HTMLElement>(".menubar-pop");
      if (!item || !host) return;
      const a = item.getBoundingClientRect();
      const b = host.getBoundingClientRect();
      const offset = b.right - (a.left + a.width / 2) - 8;
      setArrowRight(offset > 8 && offset < b.width - 24 ? offset : null);
    };
    measure();
    window.addEventListener("resize", measure);
    const cluster = document.querySelector(".menubar-status");
    const observer = cluster && "ResizeObserver" in window ? new ResizeObserver(measure) : null;
    if (cluster && observer) observer.observe(cluster);
    return () => {
      window.removeEventListener("resize", measure);
      observer?.disconnect();
    };
  }, [menuOpen, style]);

  // The sun/moon pins an appearance; until it is touched the page follows the system.
  useEffect(() => {
    const root = document.documentElement;
    if (theme) root.dataset.theme = theme;
    else delete root.dataset.theme;
  }, [theme]);
  // The menu bar stays at the top of the page; a panel left open would ride along over
  // the sections, so both panels close once the desktop scrolls out of view.
  useEffect(() => {
    const stage = stageRef.current;
    if (!stage || !("IntersectionObserver" in window)) return;
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) {
        setMenuOpen(false);
        setDockOpen(false);
      }
    }, { threshold: 0 });
    observer.observe(stage);
    return () => observer.disconnect();
  }, []);

  // The Dock's panel takes the menu bar's place while it is open; closing it hands the
  // place back where there is room for it (a wide screen), and leaves it closed on a phone.
  const toggleDock = () => {
    if (dockOpen) {
      setDockOpen(false);
      if (window.matchMedia("(min-width: 900px)").matches) setMenuOpen(true);
    } else {
      setDockOpen(true);
      setMenuOpen(false);
    }
  };

  const flipTheme = () => {
    const dark = theme ? theme === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches;
    setTheme(dark ? "light" : "dark");
  };

  const panel = (arrow: "up" | "down") =>
    style === "glass"
      ? <Panel state={state} arrow={arrow} arrowRight={arrow === "up" ? arrowRight : undefined} />
      : <TerminalPanel state={state} arrow={arrow} arrowRight={arrow === "up" ? arrowRight : undefined} />;

  return (
    <div className="desktop">
      <MenuBar open={menuOpen} onToggle={() => { setMenuOpen((v) => !v); setDockOpen(false); }} theme={theme} onTheme={flipTheme} />
      <div className="menubar-pop" aria-live="polite">
        {menuOpen && panel("up")}
        {menuOpen && (
          <div className="pop-style">
            <span className="segment" role="group" aria-label="Panel style">
              <button type="button" aria-pressed={style === "glass"} onClick={() => setStyle("glass")}>Glass</button>
              <button type="button" aria-pressed={style === "terminal"} onClick={() => setStyle("terminal")}>Terminal</button>
            </span>
          </div>
        )}
      </div>
      <div className="stage" ref={stageRef}>
        <div className="hero stage-hero">
          <h1 className="lockup">
            <Mark size={36} />
            {site.name}
          </h1>
          <p className="hero-tagline">{site.tagline}</p>
          <p className="hero-sub">Claude Code, Codex and Cursor. In the menu bar, above the Dock, and as a widget.</p>
          <div className="hero-cta">
            <a className="button" href={release.url}>
              <span className="button-prompt" aria-hidden="true">›</span>
              Download {site.name}
              <span className="button-cursor" aria-hidden="true" />
            </a>
            <span className="hero-meta">
              macOS {release.minMacOS} or later{release.size.startsWith("0.0") ? "" : ` · ${release.size}`} · Free
              <br />
              Signed and notarized · Updates itself
            </span>
          </div>
        </div>

        <div className="hero-tries stage-tries">
            <div className="hero-row">
              <span><b>Try it here.</b> The item in the menu bar, the icon in the Dock, a time in the panel, the refresh arrow, the Glass / Terminal switch under the panel.</span>
            </div>
        </div>

        <div className="dock-wrap">
          <div style={{ position: "relative", pointerEvents: "auto" }}>
            {dockOpen && <div className="dock-panel">{panel("down")}</div>}
            <Dock open={dockOpen} onToggle={toggleDock} />
          </div>
        </div>
      </div>
    </div>
  );
}
