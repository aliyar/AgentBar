"use client";

import { useState } from "react";
import { Mark } from "./AppIcon";
import type { PanelState } from "./state";
import { agentTitle, agents, clock, conversations, level, limitsFor, percent, short, type Conversation, type Limit } from "./sample";

/**
 * The Terminal panel, as the app draws it (Features/Overview/Styles/Terminal): mono, green
 * on near-black (ink on paper in light), `[ CLAUDE ]` headers, `▌` meters, `:r` by the
 * clock, `› ▊` at the foot with `:settings :quit`. The same state as the Glass panel.
 */
export function TerminalPanel({ state, arrow = "up", arrowRight }: { state: PanelState; arrow?: "up" | "down"; arrowRight?: number | null }) {
  const [flash, setFlash] = useState(false);
  const rerun = () => {
    state.refresh();
    setFlash(true);
    window.setTimeout(() => setFlash(false), 160);
  };
  return (
    <div className="tpanel" role="group" aria-label="The AgentBar panel, Terminal style">
      {(arrow === "down" || arrowRight != null) && (
        <span className={`panel-arrow ${arrow === "down" ? "panel-arrow--down" : ""}`} style={arrow === "up" ? { right: arrowRight ?? 22 } : { left: "50%", marginLeft: -8 }} aria-hidden="true" />
      )}
      <div className="t-band">
        <div className="t-head">
          <div className="t-name">
            <Mark size={13} />
            agentbar
          </div>
          <div className="t-controls">
            <button type="button" className={`t-cmd ${flash ? "is-flashing" : ""}`} onClick={rerun} title="Read again now (:refresh)" style={{ opacity: state.refreshing ? 0.5 : undefined }}>
              :r
            </button>
            <span className="t-clock">{state.refreshing ? <span className="dots" /> : state.readAt || " "}</span>
          </div>
        </div>
      </div>
      <div className="t-hairline" />
      <div className="t-body">
        {agents.map((agent, i) => (
          <div key={agent} className="t-section">
            <div className="t-section-head">
              <span className="t-h">
                [ {agentTitle[agent]} ]
                <a className="t-cmd" href={usagePage(agent)} target="_blank" rel="noopener" title={`Open ${agentTitle[agent]}'s usage page`}>
                  :usage
                </a>
              </span>
            </div>
            {limitsFor(agent).map((limit) => (
              <TRow key={limit.id} limit={limit} state={state} />
            ))}
            {i === agents.length - 1 && <div className="t-hairline" style={{ marginTop: 6 }} />}
          </div>
        ))}
        <div className="t-section">
          <span className="t-h">[ ACTIVE · {conversations.length} ]</span>
          {conversations.map((c) => (
            <TConv key={c.id} c={c} state={state} />
          ))}
        </div>
      </div>
      <div className="t-hairline" />
      <div className="t-band">
        <div className="t-foot">
          <span className="t-prompt">›</span>
          <span className="t-cursor" style={{ animationDuration: state.refreshing ? "0.55s" : undefined }}>▊</span>
          <span className="spacer" />
          <button type="button" className="t-cmd" title="Settings…">:settings</button>
          <button type="button" className="t-cmd" title="Quit AgentBar">:quit</button>
        </div>
      </div>
    </div>
  );
}

function usagePage(agent: string): string {
  switch (agent) {
    case "claude": return "https://claude.ai/settings/usage";
    case "codex": return "https://chatgpt.com/codex/settings/usage";
    default: return "https://cursor.com/dashboard?tab=usage";
  }
}

/** "Session (5h)" → "session.5h", "Weekly · all models" → "weekly.all". */
function key(title: string): string {
  return title.toLowerCase().replace(" models", "").replace(/ · /g, ".").replace(" (", ".").replace(")", "").replace(/ /g, ".");
}

function tint(pct: number): string {
  switch (level(pct)) {
    case "calm": return "rgb(var(--t-green) / 0.9)";
    case "warm": return "rgb(var(--t-green) / 0.55)";
    default: return "var(--t-alert)";
  }
}

function Blocks({ pct, blocks, size }: { pct: number; blocks: number; size: number }) {
  const lit = pct > 0 ? Math.max(1, Math.round((blocks * pct) / 100)) : 0;
  return (
    <span className="t-meter" style={{ fontSize: size, ["--tint" as string]: tint(pct) }} aria-hidden="true">
      <span className="lit">{"▌".repeat(lit)}</span>
      <span className="track">{"▌".repeat(blocks - lit)}</span>
    </span>
  );
}

function TRow({ limit, state }: { limit: Limit; state: PanelState }) {
  const time = state.showsClock && state.now
    ? clock(new Date(state.now.getTime() + limit.resetsIn * 1000), state.now)
    : short(limit.resetsIn);
  return (
    <div className="t-row">
      <span className="t-key">{key(limit.title)}</span>
      <Blocks pct={limit.percent} blocks={10} size={11} />
      <span className={`t-pct ${level(limit.percent) === "hot" ? "hot" : ""}`}>{percent(limit.percent)}</span>
      <button type="button" className="t-time" onClick={state.toggleClock} title={state.showsClock ? "Click for the time left" : "Click for the time it starts over"}>
        {time}
      </button>
    </div>
  );
}

function TConv({ c, state }: { c: Conversation; state: PanelState }) {
  const open = state.expanded === c.id;
  return (
    <button type="button" className="t-conv" onClick={() => state.toggleRow(c.id)} aria-expanded={open}>
      <span className="t-conv-line">
        <span className={`t-dot ${c.busy ? "busy" : "idle"}`}>{c.busy ? "●" : "○"}</span>
        <span className={`t-conv-name ${c.busy ? "" : "idle"}`}>{c.name.toLowerCase()}</span>
        <Blocks pct={c.contextPercent} blocks={6} size={9.5} />
        <span className={`t-conv-pct ${level(c.contextPercent) === "hot" ? "hot" : ""}`}>{percent(c.contextPercent)}</span>
      </span>
      {open && <span className="t-conv-detail">{`${c.model} · ${c.effort} · ${c.branch} · ${c.project}`.toLowerCase()}</span>}
    </button>
  );
}
