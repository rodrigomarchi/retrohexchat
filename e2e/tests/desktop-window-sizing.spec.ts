/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW13 [done] Windows on each landing page are sized by their content (one case per public page)
 * @flow PW14 [done] The showcase component window is sized by its content
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test, type Page } from "@playwright/test";
import { shot } from "../helpers/screenshots";

/**
 * Every window on a public desktop should be about the size of what it holds.
 *
 * The failure this guards against is a window sized by something other than its
 * content — a uniform layout, a copied default — which reads as broken twice
 * over: too tall and it is mostly empty chrome, too short and the reader has to
 * scroll a pane that had no reason to scroll.
 *
 * Run it as a report to calibrate sizes:
 *
 *     E2E_SIZING_REPORT=1 npx playwright test tests/desktop-window-sizing.spec.ts
 */

const REPORT = Boolean(process.env.E2E_SIZING_REPORT);

// Windows size to their content, so the failure is never empty space — it is
// shape. A window far taller than it is wide reads as a strip of text; one far
// wider than it is tall reads as a slab of chrome. Both mean the width was
// picked by a default rather than by what the window holds.
const MAX_ASPECT = 1.5; // height / width — beyond this it is a strip
const MIN_ASPECT = 0.22; // beyond this (below) it is a slab

// Shape only matters once there is enough content for shape to mean anything.
const SHAPE_FLOOR_PX = 150;

type WindowMetrics = {
  id: string;
  title: string;
  width: number;
  height: number;
  contentHeight: number;
  contentWidth: number;
  bodyHeight: number;
  empty: number;
  overflow: number;
  workspaceHeight: number;
};

async function measure(page: Page): Promise<WindowMetrics[]> {
  return page.evaluate(() => {
    const workspace = document.querySelector(".desktop__workspace");
    const workspaceHeight = workspace ? workspace.clientHeight : 0;

    return Array.from(document.querySelectorAll("[data-window-id]"))
      .filter((el) => !el.classList.contains("u-hidden"))
      .map((el) => {
        const body = el.querySelector<HTMLElement>("[data-window-body]");
        const rect = el.getBoundingClientRect();
        const titleBar = el.querySelector<HTMLElement>(
          "[data-window-titlebar]",
        );

        // scrollHeight is what the content wants; clientHeight is what it got.
        const contentHeight = body ? body.scrollHeight : 0;
        const bodyHeight = body ? body.clientHeight : 0;

        return {
          id: (el as HTMLElement).dataset.windowId ?? "",
          title: titleBar?.textContent?.trim().slice(0, 40) ?? "",
          width: Math.round(rect.width),
          height: Math.round(rect.height),
          contentHeight,
          contentWidth: body ? body.scrollWidth : 0,
          bodyHeight,
          empty: bodyHeight - contentHeight,
          overflow: contentHeight - bodyHeight,
          workspaceHeight,
        };
      });
  });
}

function report(path: string, windows: WindowMetrics[]) {
  if (!REPORT) return;
  console.log(`\n=== ${path} (workspace ${windows[0]?.workspaceHeight}px) ===`);
  console.log(
    ["id", "w", "h", "body", "content", "empty", "overflow"].join("\t"),
  );
  for (const w of windows) {
    console.log(
      [
        w.id.slice(0, 28),
        w.width,
        w.height,
        w.bodyHeight,
        w.contentHeight,
        w.empty,
        w.overflow,
      ].join("\t"),
    );
  }
}

const LANDING_PAGES = [
  "/",
  "/how-it-works",
  "/features",
  "/privacy",
  "/install",
  "/community",
  "/faq",
];

test.describe("Desktop window sizing", () => {
  for (const path of LANDING_PAGES) {
    test(`windows on ${path} are sized by their content`, async ({ page }) => {
      await page.setViewportSize({ width: 1440, height: 900 });
      await page.goto(path);
      await page.locator("[data-window-id]").first().waitFor();

      const windows = await measure(page);
      report(path, windows);
      await shot(page, `sized${path.replace(/\//g, "-")}`);

      expect(windows.length).toBeGreaterThan(0);

      const shaped = windows.filter((w) => w.contentHeight >= SHAPE_FLOOR_PX);

      const strips = shaped.filter(
        (w) => w.contentHeight / w.width > MAX_ASPECT,
      );
      expect(
        strips.map(
          (w) => `${w.id}: ${w.width}×${w.contentHeight} is a strip — widen it`,
        ),
      ).toEqual([]);

      const slabs = shaped.filter(
        (w) => w.contentHeight / w.width < MIN_ASPECT,
      );
      expect(
        slabs.map(
          (w) => `${w.id}: ${w.width}×${w.contentHeight} is a slab — narrow it`,
        ),
      ).toEqual([]);

      // The defect this whole audit came from was not one bad window: it was
      // every window inheriting the same default width, so none of them was
      // sized by anything. Widths that were actually chosen do not all match.
      if (windows.length >= 4) {
        const byWidth = new Map<number, number>();
        for (const w of windows) {
          byWidth.set(w.width, (byWidth.get(w.width) ?? 0) + 1);
        }
        const commonest = Math.max(...byWidth.values());

        expect(
          commonest / windows.length,
          `${commonest} of ${windows.length} windows share one width — they were not sized, they inherited`,
        ).toBeLessThanOrEqual(0.6);
      }

      // Nothing may spill past the desk it sits on.
      const spilling = windows.filter(
        (w) => w.height > w.workspaceHeight && w.workspaceHeight > 0,
      );
      expect(
        spilling.map(
          (w) => `${w.id}: ${w.height}px on a ${w.workspaceHeight}px desk`,
        ),
      ).toEqual([]);
    });
  }

  test("the showcase component window is sized by its content", async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/showcase/button");
    await page.locator("[data-window-id]").first().waitFor();

    const windows = await measure(page);
    report("/showcase/button", windows);

    const spilling = windows.filter(
      (w) => w.height > w.workspaceHeight && w.workspaceHeight > 0,
    );
    expect(
      spilling.map(
        (w) => `${w.id}: ${w.height}px on a ${w.workspaceHeight}px desk`,
      ),
    ).toEqual([]);
  });
});
