import { Mark } from "../demo/AppIcon";
import { DownloadButton } from "./DownloadButton";
import { release } from "../release";
import { site } from "../site";

/** The last word on every page: what it is for, and the download. */
export function SiteCTA() {
  return (
      <section className="cta" id="download">
        <div className="cta-inner">
          <Mark size={40} />
          <h2>Know where you stand before the window closes.</h2>
          <p>Every agent's quota and every running conversation, one glance away, on the Mac you are already using.</p>
          <DownloadButton where="end" big />
          <p className="cta-meta">
            Version {release.version} · {release.size.startsWith("0.0") ? "" : `${release.size} · `}{release.date} · macOS {release.minMacOS} or later · Free and open source · Signed and notarized · Updates itself
          </p>
        </div>
      </section>
  );
}
