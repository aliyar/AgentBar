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
      <body>{children}</body>
    </html>
  );
}
