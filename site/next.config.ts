import type { NextConfig } from "next";

// Static export: every page is prerendered to HTML under out/ and served by Render as a
// static site. `images.unoptimized` is the one setting the export needs.
const nextConfig: NextConfig = {
  output: "export",
  // Next writes AGENTS.md and CLAUDE.md into the site folder on every build; this project
  // keeps its instructions in the private notes repo, not in the code repo.
  agentRules: false,
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
