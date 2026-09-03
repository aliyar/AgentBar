import { release } from "./release";
import { site } from "./site";

/** The mark from Design/Icon/mark-mono.svg: strokes in the text colour, the cursor green. */
function Mark() {
  return (
    <svg viewBox="0 0 18 18" width="28" height="28" aria-hidden="true">
      <rect x="1.75" y="4.75" width="14.5" height="11.5" rx="2.4" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <polygon points="6.8,5 9,2.4 11.2,5" fill="currentColor" />
      <polyline points="5,8.4 7.4,10.5 5,12.6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="9.4" y="9" width="3.2" height="3.2" rx=".7" fill="#1f8a62" />
    </svg>
  );
}

export default function Home() {
  return (
    <main>
      <header>
        <p className="eyebrow">macOS {release.minMacOS} or later</p>
        <h1 className="lockup">
          <Mark />
          {site.name}
        </h1>
        <p className="tagline">{site.tagline}</p>
        <p className="tagline muted">In the menu bar, in the Dock, and as a widget.</p>
        <p>
          <a className="button" href={release.url}>
            Download {site.name} {release.version}
          </a>
        </p>
        <p className="meta">
          {release.size} · {release.date} · Signed and notarized · Updates itself
        </p>
      </header>

      <section>
        <h2>Read from the agents’ own files</h2>
        <p>
          Claude Code and Codex keep their rate-limit windows and running sessions in files under
          your home folder. {site.name} reads those files and nothing else: no account is
          contacted, no credential is ever seen, and nothing leaves the machine.
        </p>
      </section>

      <footer>
        <p className="muted">© 2026 GreatPixels</p>
      </footer>
    </main>
  );
}
