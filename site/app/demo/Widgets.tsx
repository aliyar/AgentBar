import { agentTitle, agents, conversations, level, limits, limitsFor, percent, short, shortTitle, type Limit } from "./sample";

/**
 * The widget in its three sizes, as AgentBarWidget/WidgetViews.swift draws it with the
 * same sample: small shows a block per agent (its fullest window); medium every window
 * as a row, or one per agent when there are more windows than the five rows it holds;
 * large a titled group per agent, then the running conversations.
 */
export function Widget({ size, variant = "card", theme }: { size: "small" | "medium" | "large"; variant?: "card" | "blocks"; theme?: "dark" | "light" }) {
  const body = size === "small" ? (variant === "blocks" ? <SmallBlocks /> : <Small />) : size === "medium" ? <Medium /> : <Large />;
  return theme ? <div className={`widget-theme widget-theme--${theme}`}>{body}</div> : body;
}

function fullestPerAgent(): Limit[] {
  return agents.map((a) => limitsFor(a).reduce((x, y) => (y.percent > x.percent ? y : x)));
}

function Ticks({ pct, count, className = "" }: { pct: number; count: number; className?: string }) {
  const lit = pct > 0 ? Math.max(1, Math.round((count * pct) / 100)) : 0;
  return (
    <span className={`w-ticks ${className}`.trim()} style={{ ["--tint" as string]: `var(--${level(pct)})` }} aria-hidden="true">
      {Array.from({ length: count }, (_, i) => (
        <i key={i} className={i < lit ? "lit" : undefined} />
      ))}
    </span>
  );
}

/** The small size with nothing chosen: a block per agent, its fullest window. */
function SmallBlocks() {
  return (
    <div className="widget widget--small" aria-label="AgentBar widget, small, every agent">
      <div className="w-blocks">
        {fullestPerAgent().map((l) => (
          <div key={l.id}>
            <div className="w-block-head">
              <b>{agentTitle[l.agent]}</b>
              <span className="w-title">{shortTitle(l.title)}</span>
              <span className="w-left">{short(l.resetsIn)}</span>
            </div>
            <div className="w-block-meter">
              <Ticks pct={l.percent} count={20} />
              <span className={`w-pct ${level(l.percent)}`}>{percent(l.percent)}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/** One window large: the agent, the window, the figure, its meter, the time left. The
 * small size draws this when a window is chosen; here Cursor's monthly plan. */
function Small() {
  const l = limits.find((x) => x.id === "cursor|monthly")!;
  const lvl = level(l.percent);
  return (
    <div className="widget widget--small" aria-label="AgentBar widget, small">
      <div className="w-card">
        <div className="w-card-agent">{agentTitle[l.agent]}</div>
        <div className="w-card-title">{shortTitle(l.title)}</div>
        <div className={`w-card-figure ${lvl}`}>{percent(l.percent)}</div>
        <Ticks pct={l.percent} count={22} />
        <div className="w-card-left">{short(l.resetsIn)}<span>left</span></div>
      </div>
    </div>
  );
}

function Row({ l, showsAgent }: { l: Limit; showsAgent: boolean }) {
  return (
    <div className="w-row">
      <span className={`w-row-label ${showsAgent ? "" : "w-row-label--short"}`}>{showsAgent ? `${agentTitle[l.agent]} · ${shortTitle(l.title)}` : shortTitle(l.title)}</span>
      <Ticks pct={l.percent} count={24} className="w-ticks--row" />
      <span className={`w-row-pct ${level(l.percent) === "hot" ? "hot" : ""}`}>{percent(l.percent)}</span>
      <span className="w-row-time">{short(l.resetsIn)}</span>
    </div>
  );
}

function Medium() {
  const rows = limits.length > 5 ? fullestPerAgent() : limits;
  return (
    <div className="widget widget--medium" aria-label="AgentBar widget, medium">
      <div className="w-groups">
        {agents.map((a) => {
          const own = rows.filter((l) => l.agent === a);
          return own.length ? (
            <div key={a} className="w-group">
              {own.map((l) => <Row key={l.id} l={l} showsAgent />)}
            </div>
          ) : null;
        })}
      </div>
    </div>
  );
}

function Large() {
  const rows = limits.length > 6 ? fullestPerAgent() : limits;
  const shown = conversations.slice(0, Math.min(4, Math.max(1, 10 - rows.length)));
  return (
    <div className="widget widget--large" aria-label="AgentBar widget, large">
      {agents.map((a) => (
        <div key={a}>
          <div className="w-caption">{agentTitle[a]}</div>
          <div className="w-group">
            {rows.filter((l) => l.agent === a).map((l) => <Row key={l.id} l={l} showsAgent={false} />)}
          </div>
        </div>
      ))}
      <div className="w-caption">Active</div>
      <div className="w-group">
        {shown.map((c) => (
          <div key={c.id} className="w-conv">
            <i className={c.busy ? "busy" : undefined} />
            <span>{c.name}</span>
            <b>{percent(c.contextPercent)}</b>
          </div>
        ))}
      </div>
    </div>
  );
}
