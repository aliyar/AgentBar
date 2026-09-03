"use client";

import { Mark } from "./AppIcon";
import { AgentLogo } from "./Logos";
import type { PanelState } from "./state";
import { agentTitle, agents, clock, conversations, level, limitsFor, percent, short, shortTitle, type Conversation, type Limit } from "./sample";

/**
 * The Glass panel, as the app draws it (Features/Overview/Styles/Glass): header with the
 * mark, the refresh arrow and the clock; a captioned rounded group per agent with a row per
 * window; Active with the running conversations; the footer. Same numbers as the app's own
 * sample; the same things move.
 */
export function Panel({ state, arrow = "up", arrowRight }: { state: PanelState; arrow?: "up" | "down"; arrowRight?: number | null }) {
  return (
    <div className="panel" role="group" aria-label="The AgentBar panel">
      {(arrow === "down" || arrowRight != null) && (
        <span className={`panel-arrow ${arrow === "down" ? "panel-arrow--down" : ""}`} style={arrow === "up" ? { right: arrowRight ?? 22 } : { left: "50%", marginLeft: -8 }} aria-hidden="true" />
      )}
      <div className="panel-head">
        <div className="panel-name">
          <Mark size={16} />
          AgentBar
        </div>
        <div className="panel-controls">
          <button type="button" className={`refresh ${state.refreshing ? "is-spinning" : ""}`} onClick={state.refresh} title="Read again now" aria-label="Read again now">
            <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M13.5 8a5.5 5.5 0 0 1-9.6 3.7M2.5 8a5.5 5.5 0 0 1 9.6-3.7" />
              <path d="M12.5 1.8v2.9h-2.9M3.5 14.2v-2.9h2.9" />
            </svg>
          </button>
          <span className="panel-clock" title="When the agents were last read">
            {state.refreshing ? <span className="dots" /> : state.readAt || " "}
          </span>
        </div>
      </div>
      <div className="hairline" />
      <div className="panel-body">
        {agents.map((agent) => (
          <section key={agent}>
            <div className="group-caption">
              <span>
                {agentTitle[agent]}
                <a className="usage-link" href={usagePage(agent)} target="_blank" rel="noopener" title={`Open ${agentTitle[agent]}'s usage page`}>
                  <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <path d="M6 3H3.5A1.5 1.5 0 0 0 2 4.5v8A1.5 1.5 0 0 0 3.5 14h8a1.5 1.5 0 0 0 1.5-1.5V10M9 2h5v5M14 2 7.5 8.5" />
                  </svg>
                </a>
              </span>
            </div>
            <div className="group">
              {limitsFor(agent).map((limit) => (
                <UsageRow key={limit.id} limit={limit} state={state} />
              ))}
            </div>
          </section>
        ))}
        <section>
          <div className="group-caption">
            <span>Active</span>
          </div>
          <div className="group">
            {conversations.map((c) => (
              <ConversationRow key={c.id} c={c} state={state} />
            ))}
          </div>
        </section>
      </div>
      <div className="hairline" />
      <div className="panel-foot">
        <button type="button" className="foot-btn" title="Settings…" aria-label="Settings">
          <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
            <path fillRule="evenodd" d="M6.9 1.5h2.2l.4 1.6c.4.1.8.3 1.1.5l1.5-.8 1.6 1.6-.8 1.5c.2.3.4.7.5 1.1l1.6.4v2.2l-1.6.4c-.1.4-.3.8-.5 1.1l.8 1.5-1.6 1.6-1.5-.8c-.3.2-.7.4-1.1.5l-.4 1.6H6.9l-.4-1.6c-.4-.1-.8-.3-1.1-.5l-1.5.8-1.6-1.6.8-1.5c-.2-.3-.4-.7-.5-1.1l-1.6-.4V6.9l1.6-.4c.1-.4.3-.8.5-1.1l-.8-1.5 1.6-1.6 1.5.8c.3-.2.7-.4 1.1-.5l.4-1.6ZM8 5.6a2.4 2.4 0 1 0 0 4.8 2.4 2.4 0 0 0 0-4.8Z" />
          </svg>
        </button>
        <button type="button" className="foot-btn" title="Quit AgentBar" aria-label="Quit AgentBar">
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true">
            <path d="M8 2v5.5" />
            <path d="M4.6 4.6a4.8 4.8 0 1 0 6.8 0" />
          </svg>
        </button>
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

function UsageRow({ limit, state }: { limit: Limit; state: PanelState }) {
  const lvl = level(limit.percent);
  const ticks = 44;
  const lit = limit.percent > 0 ? Math.max(1, Math.round((ticks * limit.percent) / 100)) : 0;
  const time = state.showsClock && state.now
    ? clock(new Date(state.now.getTime() + limit.resetsIn * 1000), state.now)
    : short(limit.resetsIn);
  return (
    <div className="row" title={`${limit.title}: ${percent(limit.percent)} used, starts over ${state.showsClock ? "at" : "in"} ${time}`}>
      <span className="row-label">{shortTitle(limit.title)}</span>
      <span className="ticks" style={{ ["--tint" as string]: `var(--${lvl})` }} aria-hidden="true">
        {Array.from({ length: ticks }, (_, i) => (
          <i key={i} className={i < lit ? "lit" : undefined} />
        ))}
      </span>
      <span className={`row-pct ${lvl === "hot" ? "hot" : ""}`}>{percent(limit.percent)}</span>
      <button type="button" className="row-time" onClick={state.toggleClock} title={state.showsClock ? "Click for the time left" : "Click for the time it starts over"}>
        {time}
      </button>
    </div>
  );
}

function ConversationRow({ c, state }: { c: Conversation; state: PanelState }) {
  const open = state.expanded === c.id;
  const lvl = level(c.contextPercent);
  return (
    <button type="button" className={`conv ${open ? "is-open" : ""}`} onClick={() => state.toggleRow(c.id)} aria-expanded={open}>
      <span className="conv-line">
        <span className={`glyph glyph--${c.agent}`}>
          <AgentLogo agent={c.agent} />
          {c.busy && <i className="dot" aria-label="working" />}
        </span>
        <span className="conv-name">{c.name}</span>
        <span className="conv-bar" style={{ ["--tint" as string]: `var(--${lvl})` }} aria-hidden="true">
          <i style={{ width: `${c.contextPercent}%` }} />
        </span>
        <span className={`conv-pct ${lvl === "hot" ? "hot" : ""}`}>{percent(c.contextPercent)}</span>
        <span className="conv-chev" aria-hidden="true">
          <svg viewBox="0 0 8 8" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <path d="M2.5 1.2 5.3 4 2.5 6.8" />
          </svg>
        </span>
      </span>
      {open && <span className="conv-detail">{`${c.model} · ${c.effort} · ${c.branch} · ${c.project}`}</span>}
    </button>
  );
}
