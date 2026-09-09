/**
 * Structured data for the home page: what the thing is, who makes it, what it costs and
 * what it answers. Search engines and the assistants that crawl for them read this rather
 * than guessing from the drawn desktop, which carries no screenshot to read.
 *
 * Everything here restates something the page already says. Nothing is asserted that the
 * page does not: no ratings, no counts, no claims we cannot stand behind.
 */
import { faq } from "./content";
import { release } from "./release";
import { ogImage, site } from "./site";

const publisher = {
  "@type": "Organization",
  "@id": `${site.url}/#maker`,
  name: site.maker,
  url: site.makerUrl,
};

export const homeSchema = {
  "@context": "https://schema.org",
  "@graph": [
    publisher,
    {
      "@type": "WebSite",
      "@id": `${site.url}/#website`,
      url: `${site.url}/`,
      name: site.name,
      description: site.description,
      inLanguage: "en",
      publisher: { "@id": publisher["@id"] },
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${site.url}/#app`,
      name: site.name,
      url: `${site.url}/`,
      description: site.description,
      abstract: site.tagline,
      applicationCategory: "DeveloperApplication",
      operatingSystem: `macOS ${release.minMacOS} or later`,
      softwareVersion: release.version,
      datePublished: release.date,
      fileSize: release.size,
      downloadUrl: release.url,
      installUrl: `${site.url}/#install`,
      image: `${site.url}${ogImage.url}`,
      featureList: [
        "Rate-limit windows for Claude Code, Codex and Cursor, with the time until each starts over",
        "Every conversation running right now, with how full its context is",
        "The same panel from the menu bar, the Dock and a widget in three sizes",
        "Reads the agents' own files and their own sign-in, read-only; nothing stored",
      ],
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD", availability: "https://schema.org/InStock" },
      license: "https://opensource.org/licenses/MIT",
      isAccessibleForFree: true,
      codeRepository: site.repo,
      author: { "@id": publisher["@id"] },
      publisher: { "@id": publisher["@id"] },
    },
    {
      "@type": "FAQPage",
      "@id": `${site.url}/#faq`,
      mainEntity: faq.map((item) => ({
        "@type": "Question",
        name: item.q,
        acceptedAnswer: { "@type": "Answer", text: item.a },
      })),
    },
  ],
} as const;

/** One `<script type="application/ld+json">`, serialised the way React wants it. */
export function jsonLd(schema: unknown) {
  return { __html: JSON.stringify(schema) };
}
