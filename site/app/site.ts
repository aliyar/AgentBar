export const site = {
  name: "AgentBar",
  url: "https://agentbar.greatpixels.com",
  maker: "GreatPixels",
  makerUrl: "https://greatpixels.com",
  support: "support@greatpixels.com",
  // The page stays light in both appearances, so one theme colour covers it: the wallpaper base.
  themeColor: "#ecdfcf",
  tagline: "What the coding agents on this Mac are doing, and how much of their quota is left.",
  description:
    "AgentBar shows the coding agents' rate-limit windows and running conversations in the macOS menu bar, above the Dock, and as a widget. Claude Code, Codex and Cursor; read from their own files and their own sign-in, read-only; nothing stored, nothing invented.",
} as const;

/**
 * The card every link preview draws — Slack, iMessage, X, LinkedIn, Discord.
 * Rendered by `make icon` into `public/og.png`; the dimensions are stated here because
 * scrapers that are handed them draw the large card on the first fetch instead of waiting
 * to measure the file. Bump `?v=` when the raster changes: the previews cache by URL.
 */
export const ogImage = {
  url: "/og.png?v=1",
  width: 1200,
  height: 630,
  type: "image/png",
  alt: "The AgentBar icon — a terminal squircle with a green block cursor — beside the name and the line: what the coding agents on this Mac are doing, and how much of their quota is left.",
} as const;

/**
 * Metadata for a document page (privacy, terms). Next replaces the layout's `openGraph`
 * and `twitter` objects wholesale rather than merging into them, so every page that states
 * its own has to restate the card as well; this is that restatement, in one place.
 */
export function pageMetadata({ title, description, path }: { title: string; description: string; path: string }) {
  const heading = `${title} · ${site.name}`;
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      type: "article" as const,
      title: heading,
      description,
      url: path,
      siteName: site.name,
      locale: "en_US",
      images: [ogImage],
    },
    twitter: { card: "summary_large_image" as const, title: heading, description, images: [ogImage] },
  };
}
