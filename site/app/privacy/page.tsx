import type { Metadata } from "next";
import Link from "next/link";
import { SiteEnd } from "../ui/SiteEnd";
import { PageHeader } from "../ui/PageHeader";
import { pageMetadata, site } from "../site";

export const metadata: Metadata = pageMetadata({
  title: "Privacy",
  description: `What ${site.name} and this website do and do not collect.`,
  path: "/privacy/",
});

export default function Privacy() {
  return (
    <>
      <PageHeader />
      <main className="sheet" id="main">
        <article className="doc">
          <h1>Privacy</h1>
        <p className="doc-date">Last updated 4 September 2026</p>
        <p className="doc-lead">
          The short version: {site.name} has no backend, no account of its own and no telemetry. Nothing about
          you, your agents or your usage is collected by us, transmitted to us, or stored anywhere but on your
          own Mac.
        </p>

        <h3>What the app reads, and where it stays</h3>
        <p>
          {site.name} reads the files the coding agents keep under your home folder: Claude Code’s and Codex’s
          rate-limit figures and session files, the tail of a running conversation’s transcript for its name and
          context figure and Cursor’s local state. It shows what it finds. It writes one file of its own: the
          latest snapshot, into its App Group container, so the widget can draw it. Settings live in macOS user
          defaults. Delete those and {site.name} starts empty. Nothing is sent to us; there is nowhere to send it.
        </p>

        <h3>What the app sends over the network</h3>
        <ul>
          <li>
            <strong>Your own agents’ accounts.</strong> To show the limits only the account knows, {site.name}
            asks each agent’s service with the sign-in that agent already keeps on this Mac: Claude through Claude
            Code’s sign-in, Codex through its ChatGPT sign-in, Cursor through the editor’s. Each is one read-only
            request every five minutes, one when the panel opens (at most once a minute), and one when you press
            refresh. The request goes to that service, as it would from the agent itself. The credential is read
            when needed and never stored, logged, displayed or sent anywhere else. Each agent’s account can be left
            out in Settings › Agents.
          </li>
          <li>
            <strong>The agents&rsquo; public status pages.</strong> To show whether each service is working,
            {" "}{site.name} reads the page that service publishes (status.claude.com, status.openai.com,
            status.cursor.com) every five minutes, and every minute while one of them reports a problem.
            These pages are public: no account is involved, no credential is sent, and the request carries nothing
            but the app&rsquo;s name. It can be turned off in Settings &rsaquo; Status.
          </li>
          <li>
            <strong>An update check.</strong> Once a day {site.name} fetches a small file from this site listing the
            latest version. That request tells our hosting provider your IP address and the app’s user agent, as
            any download would. You can turn automatic checks off in Settings › General.
          </li>
        </ul>
        <p>
          That is the complete list. There is no analytics SDK, no crash reporter, no advertising identifier.
        </p>

        <h3>What this website collects</h3>
        <p>
          Nothing of its own. This site sets no cookies, runs no analytics, and loads no fonts, scripts, images or
          trackers from third-party domains; every file it serves comes from this domain. The site is served by a
          hosting provider that keeps standard server logs (IP address, timestamp, requested file, user agent) to
          serve and protect it. We do not read them for anything else.
        </p>

        <h3>Your data rights</h3>
        <p>
          We hold no personal data about you, so there is nothing to export, correct or delete on our side. If you
          believe otherwise, or have a question,{" "}
          <a href={`mailto:${site.support}`}>write to us</a>.
        </p>

        <h3>Children</h3>
        <p>{site.name} is a developer tool with no accounts and no collected data; it is not directed at children.</p>

        <h3>Changes</h3>
        <p>If this policy changes, the date at the top changes with it.</p>

        </article>
      </main>
      <SiteEnd />
    </>
  );
}
