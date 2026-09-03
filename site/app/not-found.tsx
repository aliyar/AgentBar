import Link from "next/link";
import { Window } from "./ui/Window";
import { site } from "./site";

export default function NotFound() {
  return (
    <main className="desktop desktop--page">
      <Window title="Not found" className="window--doc">
        <p className="doc-lead">There is nothing at this address.</p>
        <p className="doc-back">
          <Link href="/">← {site.name}</Link>
        </p>
      </Window>
    </main>
  );
}
