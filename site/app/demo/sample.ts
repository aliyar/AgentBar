/**
 * The demonstration data: `Snapshot.sample` from AgentBarKit, the figures the app's own
 * previews and screenshots use, so the page and the app never disagree. Offsets are from
 * "now" so the countdowns read the same on any day; the clock variant is computed live.
 */

export type AgentId = "claude" | "codex" | "cursor";

export const agentTitle: Record<AgentId, string> = { claude: "Claude", codex: "Codex", cursor: "Cursor" };

export interface Limit {
  id: string;
  agent: AgentId;
  title: string;
  percent: number;
  /** Seconds until the window starts over. */
  resetsIn: number;
}

export interface Conversation {
  id: string;
  agent: AgentId;
  name: string;
  project: string;
  busy: boolean;
  contextPercent: number;
  contextTokens: number;
  model: string;
  effort: string;
  branch: string;
  /** Seconds since it last moved. */
  idleFor: number;
}

const H = 3600;
const D = 86400;

export const limits: Limit[] = [
  { id: "claude|session", agent: "claude", title: "5h", percent: 0.4, resetsIn: 4 * H },
  { id: "claude|weekly", agent: "claude", title: "Weekly · all models", percent: 8, resetsIn: D + H },
  { id: "claude|fable", agent: "claude", title: "Weekly · Fable", percent: 9, resetsIn: D + H },
  { id: "codex|session", agent: "codex", title: "5h", percent: 46, resetsIn: 2 * H },
  { id: "codex|weekly", agent: "codex", title: "Weekly", percent: 91, resetsIn: 4 * D },
  { id: "cursor|monthly", agent: "cursor", title: "Monthly", percent: 63.5, resetsIn: 9 * D + 5 * H },
];

export const conversations: Conversation[] = [
  {
    id: "1", agent: "claude", name: "Port the reader into the package and pin the file shapes", project: "agentbar",
    busy: true, contextPercent: 41, contextTokens: 410_000, model: "Fable 5.1", effort: "high", branch: "main", idleFor: 0,
  },
  {
    id: "2", agent: "codex", name: "Fix the appcast feed on the site", project: "agentbar",
    busy: true, contextPercent: 22, contextTokens: 220_000, model: "GPT-5", effort: "medium", branch: "site", idleFor: 60,
  },
  {
    id: "3", agent: "claude", name: "Done — the landing page builds as a static export.", project: "repobar",
    busy: false, contextPercent: 31, contextTokens: 310_000, model: "Opus 5", effort: "medium", branch: "site", idleFor: 600,
  },
  {
    id: "4", agent: "codex", name: "Waiting on review of release script", project: "repobar",
    busy: false, contextPercent: 64, contextTokens: 640_000, model: "GPT-5", effort: "high", branch: "release", idleFor: 1200,
  },
];

export const agents: AgentId[] = ["claude", "codex", "cursor"];

export function limitsFor(agent: AgentId): Limit[] {
  return limits.filter((l) => l.agent === agent);
}

/** "Weekly · all models" → "Weekly · all", as the panel's narrow column writes it. */
export function shortTitle(title: string): string {
  return title.replace(" · all models", " · all");
}

// ── Format, as AgentBarKit/Models/Format.swift writes it ────────────────────────────

/** 0.4 → "0%", 63.5 → "64%". */
export function percent(value: number): string {
  return `${Math.round(value)}%`;
}

/** 4h → "4h", 4h 52m → "4h 52m", 1d 1h → "1d 1h", 9d 5h → "9d 5h", 4d → "4d". */
export function short(seconds: number): string {
  const s = Math.max(0, Math.round(seconds));
  if (s < 60) return "now";
  if (s < H) return `${Math.floor(s / 60)}m`;
  if (s < D) {
    const h = Math.floor(s / H);
    const m = Math.floor((s % H) / 60);
    return m ? `${h}h ${m}m` : `${h}h`;
  }
  const d = Math.floor(s / D);
  const h = Math.floor((s % D) / H);
  return h ? `${d}d ${h}h` : `${d}d`;
}

/** "45m ago", "2h ago", "3d ago": the coarse form, one unit. */
export function coarse(seconds: number): string {
  const s = Math.max(0, Math.round(seconds));
  if (s < 60) return "just now";
  if (s < H) return `${Math.floor(s / 60)}m ago`;
  if (s < D) return `${Math.floor(s / H)}h ago`;
  return `${Math.floor(s / D)}d ago`;
}

/** "14:44" today, "Sat 14:44" within the week, "12 Sep" beyond, from a date. */
export function clock(date: Date, now = new Date()): string {
  const hh = String(date.getHours()).padStart(2, "0");
  const mm = String(date.getMinutes()).padStart(2, "0");
  const sameDay = date.toDateString() === now.toDateString();
  if (sameDay) return `${hh}:${mm}`;
  const diff = (date.getTime() - now.getTime()) / 1000;
  if (diff < 7 * D) {
    const day = date.toLocaleDateString("en-GB", { weekday: "short" });
    return `${day} ${hh}:${mm}`;
  }
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${date.getDate()} ${months[date.getMonth()]}`;
}

/** "410K" for a token count. */
export function compact(tokens: number): string {
  if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
  if (tokens >= 1000) return `${Math.round(tokens / 1000)}K`;
  return String(tokens);
}

/** The app's thresholds: calm below 60, warm below 85, hot from 85. */
export type Level = "calm" | "warm" | "hot";
export function level(pct: number): Level {
  return pct < 60 ? "calm" : pct < 85 ? "warm" : "hot";
}
