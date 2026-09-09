import type { Metadata } from "next";
import Link from "next/link";
import { SiteEnd } from "../ui/SiteEnd";
import { PageHeader } from "../ui/PageHeader";
import { pageMetadata, site } from "../site";

export const metadata: Metadata = pageMetadata({
  title: "Terms",
  description: `The terms under which ${site.name} is offered.`,
  path: "/terms/",
});

export default function Terms() {
  return (
    <>
      <PageHeader />
      <main className="sheet" id="main">
        <article className="doc">
          <h1>Terms</h1>
        <p className="doc-date">Last updated 3 September 2026</p>
        <p className="doc-lead">
          {site.name} is free software from {site.maker}, offered as it is. These are the few terms that come with
          it.
        </p>

        <h3>The software</h3>
        <p>
          {site.name} is free and open source under the <Link href="/license/">MIT License</Link>: you may use,
          copy, modify and distribute it, including commercially, as long as the copyright notice travels with it.
          The <a href={site.repo} target="_blank" rel="noopener">source is on GitHub</a>. It is provided “as is”,
          without warranty of any kind: it reads figures the agents and their services publish and shows them to
          you, and those figures, their timing and their meaning belong to the services that produce them.
          {" "}{site.maker} is not liable for decisions made on the strength of a number in a menu bar.
        </p>

        <h3>Your accounts</h3>
        <p>
          {site.name} uses the sign-in each agent keeps on your Mac to ask that agent’s service for your usage.
          Whether that is permitted is governed by your agreement with that service, not by us; you use this
          feature under those terms, and you can leave any agent’s account out in Settings › Agents.
        </p>

        <h3>Names and marks</h3>
        <p>
          Claude and Claude Code are marks of Anthropic; Codex and ChatGPT of OpenAI; Cursor of Anysphere. They
          are named here to say what the app reads. {site.name} is not affiliated with, endorsed by or sponsored
          by any of them. {site.name} and its mark belong to {site.maker}.
        </p>

        <h3>Updates and availability</h3>
        <p>
          Updates are delivered through this site and may change how the app works. We may stop offering the app
          or its updates at any time; a copy you already have keeps working as long as the services it reads do.
        </p>

        <h3>Privacy</h3>
        <p>
          What the app and this site do and do not collect is in the <Link href="/privacy/">privacy page</Link>.
        </p>

        <h3>Changes</h3>
        <p>If these terms change, the date at the top changes with them.</p>

        </article>
      </main>
      <SiteEnd />
    </>
  );
}
