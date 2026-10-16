import { describe, expect, it } from "vitest";
import { applyHead } from "../../../js/lib/site/head_sync.js";

function doc(html) {
  const el = document.implementation.createHTMLDocument("t");
  el.head.innerHTML = html;
  return el;
}

describe("applyHead", () => {
  it("rewrites the description, canonical and robots of the window in front", () => {
    const d = doc(`
      <meta name="description" content="old">
      <meta property="og:description" content="old">
      <meta name="twitter:description" content="old">
      <meta name="robots" content="index, follow">
      <meta property="og:url" content="https://x.test/">
      <link rel="canonical" href="https://x.test/">
    `);

    applyHead(d, {
      description: "new",
      robots: "noindex, nofollow",
      canonical: "https://x.test/faq",
    });

    expect(d.querySelector('meta[name="description"]').content).toBe("new");
    expect(d.querySelector('meta[property="og:description"]').content).toBe("new");
    expect(d.querySelector('meta[name="twitter:description"]').content).toBe("new");
    expect(d.querySelector('meta[name="robots"]').content).toBe("noindex, nofollow");
    expect(d.querySelector('meta[property="og:url"]').content).toBe("https://x.test/faq");
    expect(d.querySelector('link[rel="canonical"]').href).toBe("https://x.test/faq");
  });

  it("leaves alone what the server did not name", () => {
    const d = doc(`<meta name="description" content="kept">`);
    applyHead(d, { robots: "index, follow" });
    expect(d.querySelector('meta[name="description"]').content).toBe("kept");
  });
});
