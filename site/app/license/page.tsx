import type { Metadata } from "next";
import Link from "next/link";
import { SiteEnd } from "../ui/SiteEnd";
import { PageHeader } from "../ui/PageHeader";
import { pageMetadata, site } from "../site";

export const metadata: Metadata = pageMetadata({
  title: "License",
  description: `${site.name} is free and open source under the MIT License.`,
  path: "/license/",
});

/** The licence in full, because a link to a file in a repository is not the same as reading it. */
const mit = `MIT License

Copyright (c) 2026 GreatPixels

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.`;

export default function License() {
  return (
    <>
      <PageHeader />
      <main className="sheet" id="main">
        <article className="doc">
          <h1>License</h1>
          <p className="doc-date">Last updated 9 September 2026</p>
          <p className="doc-lead">
            {site.name} is free and open source under the MIT License. You may use, copy, modify and distribute
            it, including commercially, as long as the copyright notice and this permission notice travel with
            it. The software comes with no warranty; the <Link href="/terms/">terms</Link> say the rest.
          </p>

          <h3>The MIT License</h3>
          <pre className="doc-pre">{mit}</pre>

          <h3>The source</h3>
          <p>
            The app, its tests and this website are in one repository:{" "}
            <a href={site.repo} target="_blank" rel="noopener">github.com/aliyar/AgentBar</a>. Issues and pull
            requests are welcome there.
          </p>

          <h3>What it is built on</h3>
          <p>
            <a href="https://sparkle-project.org" target="_blank" rel="noopener">Sparkle</a> delivers the updates
            (MIT). The page's faces are Martian Mono (Evil Martians) and Atkinson Hyperlegible Next (Braille
            Institute), both under the SIL Open Font License. The agents' own marks belong to their owners, as
            the <Link href="/terms/">terms</Link> say.
          </p>
        </article>
      </main>
      <SiteEnd />
    </>
  );
}
