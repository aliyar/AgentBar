import type { NextConfig } from "next";

// Static export: every page is prerendered to HTML under out/ and served by Render as a
// static site. `images.unoptimized` is the one setting the export needs.
const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
