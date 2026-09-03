import type { MetadataRoute } from "next";
import { release } from "./release";
import { site } from "./site";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: `${site.url}/`, lastModified: release.date, changeFrequency: "monthly", priority: 1 },
    { url: `${site.url}/privacy/`, lastModified: "2026-09-03", changeFrequency: "yearly", priority: 0.3 },
    { url: `${site.url}/terms/`, lastModified: "2026-09-03", changeFrequency: "yearly", priority: 0.3 },
  ];
}
