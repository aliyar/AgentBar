import Link from "next/link";
import { Mark } from "../demo/AppIcon";
import { site } from "../site";

/**
 * The foot of every page. Its links are absolute (`/#shows`, not `#shows`) so the legal
 * pages reach the sections rather than scrolling nowhere.
 */
export function SiteFooter() {
  return (
    <footer className="footer">
      <div className="footer-inner">
        <div className="footer-brand">
          <Link className="lockup" href="/"><Mark size={18} />{site.name}</Link>
          <p>{site.tagline}</p>
          <p className="footer-fine">© 2026 {site.maker}. Made for the Mac.</p>
        </div>
        <nav className="footer-col" aria-label="The app">
          <b>The app</b>
          <Link href="/#shows">What it shows</Link>
          <Link href="/#lives">Where it lives</Link>
          <Link href="/#styles">Two styles</Link>
          <Link href="/#status">When it goes down</Link>
          <Link href="/#widget">The widget</Link>
          <Link href="/#knows">How it knows</Link>
        </nav>
        <nav className="footer-col" aria-label="Get it">
          <b>Get it</b>
          <Link href="/#download">Download</Link>
          <Link href="/#install">Install</Link>
          <Link href="/#faq">Questions</Link>
        </nav>
        <nav className="footer-col" aria-label="Project">
          <b>Project</b>
          <a href={site.repo} target="_blank" rel="noopener">GitHub repository</a>
          <a href={`${site.repo}/releases`} target="_blank" rel="noopener">All releases</a>
          <a href={`${site.repo}/issues`} target="_blank" rel="noopener">Report an issue</a>
        </nav>
        {/* Named by what is in it, as the other columns are: the maker's name said nothing
            about Support, Privacy and Terms. */}
        <nav className="footer-col" aria-label="Anything else">
          <b>Anything else</b>
          <a href={`mailto:${site.support}`}>Support</a>
          <Link href="/privacy/">Privacy</Link>
          <Link href="/terms/">Terms</Link>
          <Link href="/license/">License</Link>
        </nav>
      </div>
    </footer>
  );
}
