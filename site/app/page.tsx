import { release } from "./release";
import { site } from "./site";

export default function Home() {
  return (
    <main>
      <header>
        <p className="eyebrow">macOS {release.minMacOS} or later</p>
        <h1>{site.name}</h1>
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
