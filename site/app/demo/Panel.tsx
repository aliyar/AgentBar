"use client";

import { useState } from "react";
import { Mark } from "./AppIcon";
import { AgentLogo } from "./Logos";
import type { PanelState } from "./state";
import { agentTitle, agents, captionNotes, clock, conversations, coarse, level, limitsFor, links, percent, plans, resetCredits, short, shortTitle, status, statusLevel, statusTitle, type AgentId, type Conversation, type Limit, type ServiceStatus } from "./sample";

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
        {state.route ? (
          <button type="button" className="panel-name panel-back" onClick={state.back} title="Back to the meters">
            <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M10 3 5 8l5 5" />
            </svg>
            {agentTitle[state.route as AgentId]} status
          </button>
        ) : (
          <div className="panel-name">
            <Mark size={16} />
            AgentBar
          </div>
        )}
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
        {state.route ? (
          <StatusScreen agent={state.route as AgentId} />
        ) : (
          <>
            {agents.map((agent) => (
              <section key={agent}>
                <div className="group-caption">
                  <span className="caption-name">
                    <StatusDot level={status[agent].level} onClick={() => state.openStatus(agent)}
                      title={`${agentTitle[agent]} · ${statusTitle[status[agent].level]}. Click for everything the page lists.`} />
                    {agentTitle[agent]}
                    <span className="badge">{plans[agent]}</span>
                  </span>
                  <span className="caption-tail">
                    {captionNotes[agent] && <span className="note">{captionNotes[agent]}</span>}
                    <LinksMenu agent={agent} />
                  </span>
                </div>
                <div className="group">
                  {limitsFor(agent).map((limit) => (
                    <UsageRow key={limit.id} limit={limit} state={state} />
                  ))}
                  {resetCredits[agent] && <ResetsRow expiries={resetCredits[agent]!} state={state} />}
                </div>
              </section>
            ))}
            <section>
              <div className="group-caption">
                <span className="caption-name">Active</span>
              </div>
              <div className="group">
                {conversations.map((c) => (
                  <ConversationRow key={c.id} c={c} state={state} />
                ))}
              </div>
            </section>
          </>
        )}
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

/** The one mark this feature draws: quiet until something is actually wrong. */
function StatusDot({ level, onClick, title }: { level: ServiceStatus["level"]; onClick?: () => void; title?: string }) {
  const dot = <i className={`sdot sdot--${statusLevel(level)} ${level === "operational" ? "is-quiet" : ""}`} aria-hidden="true" />;
  if (!onClick) return dot;
  return (
    <button type="button" className="sdot-btn" onClick={onClick} title={title} aria-label={title}>
      {dot}
    </button>
  );
}

/** The `⋯` at the end of an agent's line: every page about it. */
function LinksMenu({ agent }: { agent: AgentId }) {
  return (
    <details className="more">
      <summary title={`${agentTitle[agent]} on the web`} aria-label={`${agentTitle[agent]} on the web`}>⋯</summary>
      <div className="more-menu">
        {links[agent].map((group, i) => (
          <div key={i} className="more-group">
            {group.map((link) => (
              <a key={link.url} href={link.url} target="_blank" rel="noopener">{link.title}</a>
            ))}
          </div>
        ))}
      </div>
    </details>
  );
}

/** One agent's status, as a screen of its own over the panel. */
function StatusScreen({ agent }: { agent: AgentId }) {
  const s = status[agent];
  return (
    <section className="status-screen">
      <div className="status-checked">checked 40s ago</div>
      <div className="group">
        <div className="status-summary">
          <StatusDot level={s.level} />
          <span>{s.description}</span>
        </div>
        <div className="hairline" />
        {s.components.map((c) => (
          <div key={c.name} className={`status-row ${c.watched ? "is-watched" : ""}`}>
            <StatusDot level={c.level} />
            <span className="status-name">
              {c.name}
              {c.watched && (
                <svg className="watched-eye" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" aria-label="watched">
                  <path d="M1.6 8S4 4.2 8 4.2 14.4 8 14.4 8 12 11.8 8 11.8 1.6 8 1.6 8Z" />
                  <circle cx="8" cy="8" r="1.7" />
                </svg>
              )}
            </span>
            <span className={`status-level ${c.watched && c.level !== "operational" ? "is-alert" : ""}`}>{statusTitle[c.level]}</span>
          </div>
        ))}
        <a className="status-source" href={`https://${s.host}`} target="_blank" rel="noopener">{s.host} ↗</a>
      </div>
      {s.incident && (
        <>
          <div className="group-caption"><span className="caption-name">Incident</span></div>
          <div className="group">
            <div className="status-incident">
              <span>{s.incident.name}</span>
              <span className="status-ago">{coarse(s.incident.startedIn)}</span>
            </div>
          </div>
        </>
      )}
    </section>
  );
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

/** The last line of the Codex group: how many limit resets are held; opened, when each expires. */
function ResetsRow({ expiries, state }: { expiries: number[]; state: PanelState }) {
  const [open, setOpen] = useState(false);
  return (
    <button type="button" className={`resets ${open ? "is-open" : ""}`} onClick={() => setOpen(!open)} aria-expanded={open}
      title="Credits that start a Codex limit over before its time, each with its own expiry. AgentBar only counts them; it never uses one.">
      <span className="resets-line">
        <span className="row-label">Limit resets</span>
        <span className="resets-count">{expiries.length} available</span>
        <span className="conv-chev" aria-hidden="true">
          <svg viewBox="0 0 8 8" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <path d="M2.5 1.2 5.3 4 2.5 6.8" />
          </svg>
        </span>
      </span>
      {open && expiries.map((seconds) => (
        <span key={seconds} className="resets-item">
          <span>Expires {state.now ? clock(new Date(state.now.getTime() + seconds * 1000), state.now) : ""}</span>
          <span className="resets-left">{short(seconds)} left</span>
        </span>
      ))}
    </button>
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
