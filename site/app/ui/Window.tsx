import type { ReactNode } from "react";

/**
 * A macOS window: the sections of the page are windows open on the desktop. Traffic
 * lights and a centred title in the title bar, the content below on the window colour.
 * `tone` picks the window colour independently of the page's scheme where a section
 * wants it (the Terminal-style window is always dark).
 */
export function Window({
  title,
  id,
  children,
  className = "",
  tone,
  padded = true,
}: {
  title: string;
  id?: string;
  children: ReactNode;
  className?: string;
  tone?: "dark";
  padded?: boolean;
}) {
  return (
    <section id={id} className={`window ${tone === "dark" ? "window--dark" : ""} ${className}`.trim()}>
      <div className="window-bar">
        <span className="lights" aria-hidden="true">
          <i className="light light--close" />
          <i className="light light--min" />
          <i className="light light--zoom" />
        </span>
        <h2 className="window-title">{title}</h2>
      </div>
      <div className={padded ? "window-body" : "window-body window-body--flush"}>{children}</div>
    </section>
  );
}
