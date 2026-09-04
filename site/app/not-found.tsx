import Link from "next/link";
import { SiteEnd } from "./ui/SiteEnd";
import { PageHeader } from "./ui/PageHeader";
import { site } from "./site";

export default function NotFound() {
  return (
    <>
      <PageHeader />
      <main className="sheet" id="main">
        <article className="doc">
          <h1>Not found</h1>
          <p className="doc-lead">There is nothing at this address.</p>
          <p>
            <Link href="/">Back to {site.name}</Link>
          </p>
        </article>
      </main>
      <SiteEnd />
    </>
  );
}
