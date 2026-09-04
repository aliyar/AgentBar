import { SiteCTA } from "./SiteCTA";
import { SiteFooter } from "./SiteFooter";

/**
 * The foot of every page: the last word and the footer, on the wallpaper the desktop
 * started on. The ground is part of it, so it travels with them rather than being left
 * behind on the home page.
 */
export function SiteEnd() {
  return (
    <div className="desktop-end">
      <SiteCTA />
      <SiteFooter />
    </div>
  );
}
