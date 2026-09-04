"use client";

import { useEffect, useState } from "react";
import { MenuBar } from "../demo/MenuBar";
import { Panel } from "../demo/Panel";
import { usePanelState } from "../demo/state";
import { useTheme } from "../demo/useTheme";

/**
 * The same head the home page has: its menu bar strip, with the same panel under the same
 * item. A page that is not the desktop still has a menu bar, and the item on it opens what
 * it opens everywhere else rather than sending the reader somewhere.
 */
export function PageHeader() {
  const [open, setOpen] = useState(false);
  const { theme, flip } = useTheme();
  const state = usePanelState();

  // A click anywhere else closes it, and so does Escape, as on the desktop.
  useEffect(() => {
    if (!open) return;
    const dismiss = (event: MouseEvent) => {
      const target = event.target as Element | null;
      if (target?.closest(".menubar-pop, #agentbar-item")) return;
      setOpen(false);
    };
    const escape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("pointerdown", dismiss);
    document.addEventListener("keydown", escape);
    return () => {
      document.removeEventListener("pointerdown", dismiss);
      document.removeEventListener("keydown", escape);
    };
  }, [open]);

  return (
    <>
      <MenuBar open={open} onToggle={() => setOpen((v) => !v)} theme={theme} onTheme={flip} />
      <div className="menubar-pop" aria-live="polite">
        {open && <Panel state={state} arrow="up" arrowRight={null} />}
      </div>
    </>
  );
}
