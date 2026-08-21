/**
 * @section P - Performance Budgets
 * @flow PF1 [done] /connect stays inside its document-size and DOM-node budget
 * @flow PF2 [done] A help topic stays inside its document-size and DOM-node budget
 * @flow PF3 [done] Every icon is a sprite reference and none draws its art inline
 * @flow PF4 [done] The sprite really resolves — a referenced icon has painted pixels
 * @flow PF5 [done] The second page pays nothing for the sprite
 * @flow PF6 [done] The sprite is preloaded in the head, not discovered mid-body
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { PERF_BUDGETS } from "../helpers/perfBudgets";
import { samplePerf, sampleResources } from "../helpers/perfProbe";

const SPRITE = /\/assets\/icons\/sprite[-.]/;

test.describe("Payload budgets", () => {
  test("/connect stays inside its document and DOM budget (M)", async ({
    page,
  }) => {
    await page.goto("/connect");
    await page.waitForLoadState("load");

    const sample = await samplePerf(page);

    expect(sample.navBytes).toBeLessThanOrEqual(PERF_BUDGETS.connect.navBytes);
    expect(sample.domNodes).toBeLessThanOrEqual(PERF_BUDGETS.connect.domNodes);
  });

  test("a help topic stays inside its document and DOM budget (M)", async ({
    page,
  }) => {
    await page.goto("/chat/help");
    await page.waitForLoadState("load");

    const sample = await samplePerf(page);

    expect(sample.navBytes).toBeLessThanOrEqual(PERF_BUDGETS.help.navBytes);
    expect(sample.domNodes).toBeLessThanOrEqual(PERF_BUDGETS.help.domNodes);
  });

  test("every icon points at the sprite and none draws inline (M)", async ({
    page,
  }) => {
    for (const path of ["/connect", "/chat/help"]) {
      await page.goto(path);
      await page.waitForLoadState("load");

      const counts = await page.evaluate(() => ({
        svgs: document.querySelectorAll("svg").length,
        uses: document.querySelectorAll("svg use").length,
        shapes: document.querySelectorAll("svg rect, svg polygon, svg ellipse")
          .length,
      }));

      expect(counts.svgs, `${path} renders no icons at all`).toBeGreaterThan(0);
      expect(
        counts.uses,
        `${path} has an <svg> that is not a sprite reference`,
      ).toBe(counts.svgs);
      expect(counts.shapes, `${path} still inlines icon art`).toBe(0);
    }
  });

  test("the sprite really resolves — icons have painted pixels (M)", async ({
    page,
  }) => {
    await page.goto("/connect");
    await page.waitForLoadState("load");

    // An external <use> that fails to resolve still leaves the <svg> in the DOM
    // at its CSS size, so a node count cannot tell a working icon from a broken
    // one. The shadow content can: it only exists once the sprite has loaded.
    const resolved = await page
      .locator("svg use")
      .first()
      .evaluate((node) => {
        const svg = node.closest("svg") as SVGGraphicsElement;
        const box = svg.getBoundingClientRect();
        return {
          width: box.width,
          height: box.height,
          href: node.getAttribute("href"),
        };
      });

    expect(resolved.href).toMatch(SPRITE);
    expect(resolved.width).toBeGreaterThan(0);
    expect(resolved.height).toBeGreaterThan(0);

    const sprite = await page.request.get(resolved.href!.split("#")[0]);
    expect(sprite.status()).toBe(200);
    expect(sprite.headers()["content-type"]).toContain("svg");
    expect(await sprite.text()).toContain("<symbol");
  });

  test("the sprite costs nothing on the second page (S)", async ({ page }) => {
    await page.goto("/connect");
    await page.waitForLoadState("load");

    const first = (await sampleResources(page)).find((entry) =>
      SPRITE.test(entry.url),
    );
    expect(first, "the sprite was never fetched").toBeTruthy();

    await page.goto("/chat/help");
    await page.waitForLoadState("load");

    const second = (await sampleResources(page)).find((entry) =>
      SPRITE.test(entry.url),
    );

    // Locally the sprite is served undigested, so the browser revalidates and
    // gets a 304 — headers, not 233 KB of drawings. In production phx.digest
    // fingerprints it and the `?vsn=d` cache-control means not even that.
    // Either way, the second page must not pay for the art again.
    expect(second?.transferSize ?? 0).toBeLessThan(5_000);
    expect(second?.transferSize ?? 0).toBeLessThan(first!.transferSize);
  });

  test("the sprite is announced in the head, not discovered in the body (S)", async ({
    page,
  }) => {
    await page.goto("/connect");
    await page.waitForLoadState("load");

    const preloaded = await page.evaluate(
      () =>
        !!document.head.querySelector(
          'link[rel="preload"][as="image"][href*="/assets/icons/sprite"]',
        ),
    );
    expect(preloaded).toBe(true);

    const resources = await sampleResources(page);
    const sprite = resources.find((entry) => SPRITE.test(entry.url));
    const css = resources.find((entry) =>
      entry.url.includes("/assets/css/retrohex"),
    );

    expect(sprite, "the sprite was never fetched").toBeTruthy();
    expect(css, "the stylesheet was never fetched").toBeTruthy();
    // Preloaded, so it starts with the stylesheet rather than after the parser
    // has walked the whole body looking for the first <use>.
    expect(sprite!.startTime).toBeLessThan(css!.responseEnd);
  });
});
