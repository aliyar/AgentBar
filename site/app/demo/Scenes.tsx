"use client";

import { AppIcon, Mark } from "./AppIcon";
import { Dock } from "./Dock";
import { AgentLogo } from "./Logos";
import { StatusItem } from "./MenuBar";
import { Panel } from "./Panel";
import { TerminalPanel } from "./TerminalPanel";
import { Widget } from "./Widgets";
import { usePanelState } from "./state";

/**
 * The scenes below the desktop: the app's parts, drawn and annotated, each with the few
 * words it needs. Nothing here is a picture of the app; the panels are the same components
 * the hero runs, with their own state.
 */

/** The panel with numbered callouts on what it shows. */
export function AnatomyScene() {
  const state = usePanelState();
  return (
    <div className="anatomy">
      <div className="anatomy-figure">
      <div className="anatomy-panel">
        <Panel state={state} arrow="up" arrowRight={null} />
        <Callout n={1} top={150} side="left" />
        <Callout n={2} top={150} side="right" />
        <Callout n={3} top={462} side="left" />
        <Callout n={4} top={462} side="right" />
      </div>
      </div>
      <ol className="anatomy-notes">
        <li><span><b>Every window, as a meter.</b> The 5-hour and weekly windows, and a week per model, for Claude; the same two for Codex; the plan's month for Cursor. Green, amber, then red as it fills.</span></li>
        <li><span><b>The time until it starts over.</b> Click any time and every reset shows as the clock time instead.</span></li>
        <li><span><b>What is running right now.</b> Named by what was last said in it, with a breathing dot while it works. Click for the model, effort and branch; click again to bring its terminal or editor forward.</span></li>
        <li><span><b>How full its context is.</b> A real percentage when the limit is known; the tokens when it is not.</span></li>
      </ol>
    </div>
  );
}

function Callout({ n, top, side }: { n: number; top: number; side: "left" | "right" }) {
  return (
    <span className={`callout callout--${side}`} style={{ top }} aria-hidden="true">
      <i />
      <b>{n}</b>
    </span>
  );
}

/** Glass and Terminal, side by side, the same numbers. */
export function StylesScene() {
  const glass = usePanelState();
  const terminal = usePanelState();
  return (
    <div className="styles-scene">
      <figure>
        <Panel state={glass} arrow="up" arrowRight={null} />
        <figcaption>Glass</figcaption>
      </figure>
      <figure>
        <TerminalPanel state={terminal} arrow="up" arrowRight={null} />
        <figcaption>Terminal</figcaption>
      </figure>
    </div>
  );
}

/** The three places, each as the object itself. */
export function PlacesScene() {
  const dockPanel = usePanelState();
  return (
    <div className="places">
      <figure className="place">
        <div className="place-figure">
          <div className="strip">
            <span className="strip-left"><Mark size={14} /> AgentBar</span>
            <span className="strip-right">
              <StatusItem gauge={false} />
              <StatusItem gauge />
              <span className="strip-clock">Thu 14:05</span>
            </span>
          </div>
        </div>
        <figcaption>
          <b>The menu bar</b>
          The symbol, or a bar per window with the time left on one of them. A click opens the panel.
        </figcaption>
      </figure>
      <figure className="place">
        <div className="place-figure">
          <div className="mini-dock">
            <div className="mini-pop" aria-hidden="true">
              <Panel state={dockPanel} arrow="down" />
            </div>
            <span className="mini-tile"><AppIcon size={44} /><i /></span>
          </div>
        </div>
        <figcaption>
          <b>The Dock</b>
          An icon in the Dock and ⌘-Tab if you want one. A click opens the same panel above it, or a window; ⌘0 opens the window from anywhere.
        </figcaption>
      </figure>
      <figure className="place">
        <div className="place-figure">
          <Widget size="small" />
        </div>
        <figcaption>
          <b>The widget</b>
          Three sizes for the desktop and Notification Center, each with its own theme and its own choice of windows.
        </figcaption>
      </figure>
    </div>
  );
}

/** The widgets where they live: on a Mac's desktop, drawn as a laptop. */
export function LaptopScene() {
  return (
    <figure className="laptop" aria-label="The three widget sizes on a Mac desktop">
      <div className="laptop-lid">
        <div className="laptop-screen">
          <div className="laptop-bar">
            <span className="laptop-bar-left">
              <svg viewBox="0 0 16 16" width="11" height="11" fill="currentColor" aria-hidden="true"><path d="M11.2 8.5c0-1.4.8-2.2 1.7-2.8-.6-.9-1.6-1.5-2.7-1.5-1.1-.1-2.1.7-2.6.7-.6 0-1.4-.6-2.3-.6C3.9 4.4 2.5 5.7 2.5 8c0 1 .2 2 .6 3 .5 1.3 1.6 3.2 2.7 3.2.8 0 1.2-.6 2.3-.6s1.4.6 2.3.6c1.1 0 2.1-1.8 2.6-3.1-1.2-.6-1.8-1.5-1.8-2.6ZM9.6 3.3c.5-.6.8-1.4.7-2.2-.7.1-1.5.5-2 1.1-.5.5-.8 1.3-.7 2.1.8 0 1.5-.4 2-1Z" /></svg>
              <b>Finder</b><span>File</span><span>Edit</span><span>View</span><span>Go</span><span>Window</span><span>Help</span>
            </span>
            <span className="laptop-bar-right">
              <StatusItem gauge />
              <span>Thu 14:05</span>
            </span>
          </div>
          <div className="laptop-desktop">
            <div className="laptop-widgets">
              <div className="laptop-widgets-left">
                <div className="laptop-widgets-smalls">
                  <Widget size="small" variant="blocks" />
                  <Widget size="small" />
                </div>
                <Widget size="medium" theme="dark" />
              </div>
              <Widget size="large" />
            </div>
            <div className="laptop-dock">
              <Dock open={false} onToggle={() => {}} />
            </div>
          </div>
        </div>
      </div>
      <div className="laptop-base"><i /></div>
    </figure>
  );
}

/** Three things the app will not invent, each shown as the app shows it. */
export function HonestyScene() {
  return (
    <div className="honesty-scene">
      <figure>
        <div className="evidence">
          <div className="row" style={{ padding: "7px 10px" }}>
            <span className="row-label">Weekly · all</span>
            <span className="ticks" aria-hidden="true">{Array.from({ length: 44 }, (_, i) => <i key={i} />)}</span>
            <span className="row-pct">0%</span>
            <span className="row-time" style={{ cursor: "default" }}>—</span>
          </div>
        </div>
        <figcaption><b>“—”</b> A window that has already started over, before the agent writes a fresh figure. Not a guess.</figcaption>
      </figure>
      <figure>
        <div className="evidence">
          <div className="group-caption" style={{ margin: 0, padding: "9px 10px" }}>
            <span>Codex</span>
            <span className="note">3h ago</span>
          </div>
        </div>
        <figcaption><b>“3h ago”</b> A figure old enough that you should know how old. The panel says so beside the agent's name.</figcaption>
      </figure>
      <figure>
        <div className="evidence">
          <div className="conv" style={{ cursor: "default" }}>
            <span className="conv-line">
              <span className="glyph glyph--claude"><AgentLogo agent="claude" /><i className="dot" /></span>
              <span className="conv-name">Port the reader into the package</span>
              <span className="conv-pct" style={{ width: "auto" }}>410K</span>
            </span>
          </div>
        </div>
        <figcaption><b>“410K”</b> A context whose limit is not written anywhere shows its tokens rather than a made-up percentage.</figcaption>
      </figure>
    </div>
  );
}
