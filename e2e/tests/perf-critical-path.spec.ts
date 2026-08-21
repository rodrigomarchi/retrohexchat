/**
 * @section P - Performance Budgets
 * @flow PF7 [done] With RUM off, the Faro SDK is never downloaded
 * @flow PF8 [done] The RUM entrypoint stays a gate and never carries the SDK
 * @flow PF9 [done] No third-party stylesheet blocks the first paint
 * @flow PF10 [done] /connect paints inside its FCP and LCP budget
 * @flow PF11 [done] Every content-addressed asset is cached immutably, never revalidated
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { VITALS_BUDGETS } from "../helpers/perfBudgets";
import { samplePerf, sampleResources } from "../helpers/perfProbe";

const FARO_SDK = /faro-faro_sdk-/;

test.describe("Critical path", () => {
  test("with RUM off, the Faro SDK never downloads (M)", async ({ page }) => {
    // The e2e server is not :prod, so `faro_enabled` is false. The gate has to
    // answer from the metas alone — before any import — or the 262 KB SDK ships
    // to every reader of a page that will not send a single beacon.
    const requested: string[] = [];
    page.on("request", (request) => {
      if (FARO_SDK.test(request.url())) requested.push(request.url());
    });

    await page.goto("/connect");
    await page.waitForLoadState("networkidle");

    expect(requested, "the SDK downloaded despite RUM being disabled").toEqual(
      [],
    );
  });

  test("the RUM entrypoint carries the gate, not the SDK (M)", async ({
    page,
  }) => {
    // Whether the SDK loads *after* idle can only be seen where the gate lets it
    // load at all, and it refuses localhost by design — that case is pinned in
    // assets/test/lib/telemetry/faro_gate.test.js. What the browser can answer
    // here is the regression that actually shipped: the entrypoint every page
    // view downloads used to be the whole 262 KB SDK.
    await page.goto("/connect");
    await page.waitForLoadState("load");

    const entry = (await sampleResources(page)).find((resource) =>
      /\/assets\/js\/faro_entry/.test(resource.url),
    );

    expect(entry, "the RUM entrypoint was never loaded").toBeTruthy();

    const body = await (await page.request.get(entry!.url)).text();

    expect(
      body.length,
      "the RUM entrypoint is carrying the SDK again",
    ).toBeLessThan(8_000);
    expect(
      body,
      "the SDK is statically imported instead of gated behind a dynamic import",
    ).not.toContain("@grafana/faro-web-sdk");
  });

  test("no third-party stylesheet blocks the first paint (M)", async ({
    page,
  }) => {
    // Asserted against the served HTML, not the live DOM: by the time a spec can
    // read `media`, the `onload` handler has already promoted it to "all", so the
    // DOM cannot tell a deferred stylesheet from one that was never deferred.
    // And on loopback a blocking stylesheet still finishes before FCP, so timing
    // cannot either. What the browser acts on is the markup it received.
    for (const path of ["/connect", "/chat/help", "/"]) {
      const html = await (await page.request.get(path)).text();
      const outsideNoscript = html.replace(
        /<noscript>[\s\S]*?<\/noscript>/g,
        "",
      );
      const links =
        outsideNoscript.match(/<link[^>]*fonts\.googleapis\.com[^>]*>/g) ?? [];

      expect(
        links.length,
        `${path} lost its web font entirely`,
      ).toBeGreaterThan(0);

      for (const link of links) {
        if (!link.includes('rel="stylesheet"')) continue;
        expect(
          link,
          `${path} blocks the first paint on a third-party stylesheet`,
        ).toContain('media="print"');
      }
    }
  });

  test("/connect paints inside its vitals budget (S)", async ({ page }) => {
    await page.goto("/connect");
    await page.waitForLoadState("load");
    // LCP keeps updating until the first interaction, so give the page a beat
    // to settle before reading it.
    await page.waitForTimeout(500);

    const sample = await samplePerf(page);

    expect(sample.fcp).not.toBeNull();
    expect(sample.fcp!).toBeLessThan(VITALS_BUDGETS.fcp);

    if (sample.lcp !== null) {
      expect(sample.lcp).toBeLessThan(VITALS_BUDGETS.lcp);
    }
  });

  test("a content-addressed chunk is never revalidated (M)", async ({
    page,
  }) => {
    // A URL whose bytes can never change should be asked for once and never
    // again. Production's nginx log showed the opposite: nine 304s per page
    // view on esbuild's dynamic-import chunks, whose URL the bundler writes
    // into the bundle — so it never carries the ?vsn that earns `immutable`.
    //
    // Scoped to the chunks because only they are content-addressed by name.
    // Everything else earns `immutable` from its ?vsn, which exists only after
    // phx.digest — a production build, not this one. That half is pinned in
    // test/retro_hex_chat_web/endpoint_static_test.exs.
    await page.goto("/connect");
    await page.waitForLoadState("networkidle");

    const chunks = (await sampleResources(page)).filter((entry) =>
      new URL(entry.url).pathname.startsWith("/assets/js/chunks/"),
    );

    expect(chunks.length, "no lazy chunk was loaded at all").toBeGreaterThan(0);

    const revalidating: string[] = [];
    for (const chunk of chunks) {
      const cacheControl =
        (await page.request.get(chunk.url)).headers()["cache-control"] ?? "";
      if (!cacheControl.includes("immutable")) {
        revalidating.push(`${chunk.url} -> "${cacheControl}"`);
      }
    }

    expect(
      revalidating,
      `these are asked for again on every page view:\n${revalidating.join("\n")}`,
    ).toEqual([]);
  });
});
