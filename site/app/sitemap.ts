import type { MetadataRoute } from "next";
import { release } from "./release";
import { site } from "./site";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return [{ url: `${site.url}/`, lastModified: release.date, changeFrequency: "monthly", priority: 1 }];
}
