import type { Page } from "@playwright/test";

/**
 * What one page load cost, read back from the browser's own Performance API.
 *
 * The same numbers Grafana Faro reports as RUM, so a spec can assert on them
 * against a local server and the load harness can record them per simulated
 * user and compare the two.
 */
export type PerfSample = {
  /** Elements in the document — what the main thread had to build. */
  domNodes: number;
  /** Uncompressed bytes of the document itself. */
  navBytes: number;
  /** Bytes actually transferred for the document, compression included. */
  navTransferBytes: number;
  ttfb: number;
  fcp: number | null;
  lcp: number | null;
};

/** Reads the sample for whatever is currently loaded in `page`. */
export async function samplePerf(page: Page): Promise<PerfSample> {
  return page.evaluate(() => {
    const nav = performance.getEntriesByType("navigation")[0] as
      | PerformanceNavigationTiming
      | undefined;
    const paint = performance
      .getEntriesByType("paint")
      .find((entry) => entry.name === "first-contentful-paint");
    const lcpEntries = performance.getEntriesByType("largest-contentful-paint");
    const lcp = lcpEntries.length
      ? lcpEntries[lcpEntries.length - 1]
      : undefined;

    return {
      domNodes: document.querySelectorAll("*").length,
      navBytes: nav?.decodedBodySize ?? 0,
      navTransferBytes: nav?.transferSize ?? 0,
      ttfb: nav ? nav.responseStart - nav.requestStart : 0,
      fcp: paint ? paint.startTime : null,
      lcp: lcp ? lcp.startTime : null,
    };
  });
}

/**
 * Every resource the page fetched, as `{url, startTime, responseEnd}`.
 *
 * Ordering matters as much as size here: whether the telemetry bundle arrives
 * before or after `load`, and whether the websocket waits on the locale chunk,
 * are both questions about when a request started, not how big it was.
 */
export async function sampleResources(page: Page) {
  return page.evaluate(() =>
    performance.getEntriesByType("resource").map((entry) => ({
      url: entry.name,
      startTime: entry.startTime,
      responseEnd: (entry as PerformanceResourceTiming).responseEnd,
      transferSize: (entry as PerformanceResourceTiming).transferSize,
    })),
  );
}

/** When the `load` event fired, for comparing against a resource's `startTime`. */
export async function loadEventEnd(page: Page): Promise<number> {
  return page.evaluate(() => {
    const nav = performance.getEntriesByType("navigation")[0] as
      | PerformanceNavigationTiming
      | undefined;
    return nav?.loadEventEnd ?? 0;
  });
}
