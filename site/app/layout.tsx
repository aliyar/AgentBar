import type { Metadata } from "next";
import "./globals.css";
import { site } from "./site";

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: site.name, template: `%s · ${site.name}` },
  description: site.description,
  openGraph: {
    type: "website",
    url: site.url,
    siteName: site.name,
    title: site.name,
    description: site.tagline,
    images: ["/og.png"],
  },
  twitter: { card: "summary_large_image", title: site.name, description: site.tagline, images: ["/og.png"] },
  alternates: { canonical: "/" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="preload" href="/fonts/MartianMonoVF.woff2" as="font" type="font/woff2" crossOrigin="anonymous" />
        <link rel="preload" href="/fonts/AtkinsonHyperlegibleNextVF.woff2" as="font" type="font/woff2" crossOrigin="anonymous" />
      </head>
      <body>
        {/* The direction contract, as an HTML comment in the emitted markup so the build can be audited against it. */}
        <div
          hidden
          dangerouslySetInnerHTML={{
            __html: `<!--
          THESIS: The page is a Mac desktop with AgentBar living on it everywhere at once.
          It refuses the hero / big screenshot / feature-grid scaffold: nothing is a picture
          of the app; everything is the app, drawn and working.
          OWN-WORLD: a macOS desktop. Warm wallpaper; the menu bar strip; the glass panel;
          the widgets on their own grounds; the Dock. Sections are windows on the desktop,
          with traffic lights and a title. System font; one accent, the cursor green;
          light and dark follow the system, as the app does.
          STORY: the visitor sees the item in the menu bar, the panel under it, the widgets
          and the Dock icon in one glance, understands "everywhere", clicks and sees the
          same panel open from each, believes the figures because they behave like the
          app's, and downloads from the window on the left.
          FIRST VIEWPORT: the menu bar across the top, the gauge at its right; the panel
          open beneath the item; at left a plain window with the mark, the name, the
          tagline and the download; at right a small and a medium widget; the Dock across
          the bottom with the icon and its running dot.
          FORM: the desktop itself; candidate 1 of the grounded list, taken from the pick
          card; seed 41eef9a1; code-led.
          FINISH: unreviewed and undocumented is unfinished; this build ends with the
          finish review, the verdict, DESIGN.md, and every shipping raster carrying its
          provenance.
        -->`,
          }}
        />
        {children}
      </body>
    </html>
  );
}
