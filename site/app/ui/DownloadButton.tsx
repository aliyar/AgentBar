"use client";

import { release } from "../release";
import { site } from "../site";

/** Where the click was, so the two buttons can be told apart in the report. */
export type DownloadWhere = "hero" | "end";

/**
 * A click is the nearest thing a static site has to a download, and Google Analytics gets
 * it as an event with the version. Called by every way down to the file, since a link that
 * counted in one place and not another would report a number that is quietly wrong. `app`
 * rides along so the event says which app it belongs to on its own.
 */
export function countDownload(where: DownloadWhere) {
  const w = window as unknown as { gtag?: (...args: unknown[]) => void };
  w.gtag?.("event", "download", { app: "agentbar", version: release.version, where, file: release.url.split("/").pop() });
}

/**
 * The download button. The link itself is a plain one, so it works with analytics blocked
 * or scripts off; `big` is the one at the end of the page.
 */
export function DownloadButton({ where, big = false }: { where: DownloadWhere; big?: boolean }) {
  return (
    <a className={big ? "button button--big" : "button"} href={release.url} onClick={() => countDownload(where)}>
      <span className="button-prompt" aria-hidden="true">›</span>
      Download {site.name}
      <span className="button-cursor" aria-hidden="true" />
    </a>
  );
}
