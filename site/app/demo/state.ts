"use client";

import { useCallback, useEffect, useRef, useState } from "react";

/** What the panel demo remembers between its two openings (menu bar and Dock) and its two styles. */
export interface PanelState {
  /** Reset times as the clock time they start over, instead of the time left. */
  showsClock: boolean;
  toggleClock: () => void;
  /** A read is in flight: the arrow turns, the clock walks "...". */
  refreshing: boolean;
  refresh: () => void;
  /** "14:05" when the agents were last read; set after mount so the server and the client agree. */
  readAt: string;
  /** The conversation whose details are open. */
  expanded: string | null;
  toggleRow: (id: string) => void;
  /** The clock's reference, set after mount. */
  now: Date | null;
  /** Which screen the panel shows: the overview, or one agent's status pushed over it. */
  route: string | null;
  openStatus: (agent: string) => void;
  back: () => void;
}

function hhmm(date: Date): string {
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

export function usePanelState(initialRoute: string | null = null): PanelState {
  const [showsClock, setShowsClock] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [readAt, setReadAt] = useState("");
  const [now, setNow] = useState<Date | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [route, setRoute] = useState<string | null>(initialRoute);
  const timer = useRef<number | null>(null);

  useEffect(() => {
    const date = new Date();
    setNow(date);
    setReadAt(hhmm(date));
    return () => {
      if (timer.current) window.clearTimeout(timer.current);
    };
  }, []);

  const refresh = useCallback(() => {
    if (refreshing) return;
    setRefreshing(true);
    timer.current = window.setTimeout(() => {
      const date = new Date();
      setNow(date);
      setReadAt(hhmm(date));
      setRefreshing(false);
    }, 900);
  }, [refreshing]);

  return {
    showsClock,
    toggleClock: () => setShowsClock((v) => !v),
    refreshing,
    refresh,
    readAt,
    expanded,
    toggleRow: (id) => setExpanded((open) => (open === id ? null : id)),
    now,
    route,
    openStatus: (agent) => setRoute(agent),
    back: () => setRoute(null),
  };
}
