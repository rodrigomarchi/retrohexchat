/**
 * @section T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T17 [done] Every desktop hangs the wallpaper, and the file behind it really loads
 * @flow T18 [done] A phone-width viewport hangs the tall wallpaper instead of the wide one
 * @flow T19 [done] The wide wallpaper is preloaded in the head; the tall one deliberately is not
 *
 * The wallpaper travels from Elixir to CSS through a custom property, because
 * its URL carries a content hash no stylesheet can spell. Every link in that
 * chain is invisible to ExUnit: a property that renders but names a path Plug
 * never serves, a `background-image` the cascade drops, a media query that
 * disagrees with the window manager about what counts as a phone. Only a real
 * browser fetching a real file can tell.
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, type Page } from "@playwright/test";

// The width the window manager stacks at (STACK_BREAKPOINT in
// window_manager.js) and the width window-manager.css swaps the art at. The
// point of testing either side of it is that the two must not drift apart.
const STACK_BREAKPOINT = 768;

/** The URL the desk is actually painting, as the browser resolved it. */
async function paintedWallpaper(page: Page): Promise<string> {
  const workspace = page.locator(".desktop__workspace").first();
  await expect(workspace).toBeVisible();

  return workspace.evaluate(
    (el) => getComputedStyle(el).backgroundImage as string,
  );
}

test.describe("Desktop wallpaper", () => {
  test("every desktop hangs the wide wallpaper and the file loads (M)", async ({
    page,
  }) => {
    const failed: string[] = [];
    page.on("response", (r) => {
      if (r.url().includes("/images/desktop/") && r.status() >= 400) {
        failed.push(`${r.status()} ${r.url()}`);
      }
    });

    await page.setViewportSize({ width: 1280, height: 800 });

    // The four surfaces a reader can reach that are built on `desktop/1`.
    for (const path of ["/", "/connect", "/chat/help"]) {
      await page.goto(path);
      await page.waitForLoadState("load");

      const painted = await paintedWallpaper(page);

      expect(painted, `no wallpaper painted on ${path}`).toContain(
        "/images/desktop/wallpaper_desktop",
      );
    }

    expect(failed, "the wallpaper 404'd").toEqual([]);

    // Painted is not the same as decoded: a served-but-corrupt file still
    // yields a background-image string. Ask the browser to decode it.
    const url = (await paintedWallpaper(page)).replace(/^url\("?|"?\)$/g, "");
    const size = await page.evaluate(async (src) => {
      const img = new Image();
      img.src = src;
      await img.decode();
      return { w: img.naturalWidth, h: img.naturalHeight };
    }, url);

    expect(size.w).toBeGreaterThan(0);
    expect(size.w).toBeGreaterThan(size.h); // the wide one is wide
  });

  test("a phone-width viewport hangs the tall wallpaper (M)", async ({
    page,
  }) => {
    await page.setViewportSize({ width: STACK_BREAKPOINT - 1, height: 900 });
    await page.goto("/connect");
    await page.waitForLoadState("load");

    expect(await paintedWallpaper(page)).toContain("wallpaper_mobile");

    // One pixel wider is a desk, and must swap back — this is the assertion
    // that catches the media query drifting off STACK_BREAKPOINT.
    await page.setViewportSize({ width: STACK_BREAKPOINT, height: 900 });
    await expect
      .poll(() => paintedWallpaper(page))
      .toContain("wallpaper_desktop");
  });

  test("the wide wallpaper is preloaded, the tall one is not (M)", async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1280, height: 800 });

    const fetched: string[] = [];
    page.on("response", (r) => {
      if (r.url().includes("/images/desktop/")) fetched.push(r.url());
    });

    await page.goto("/connect");
    await page.waitForLoadState("load");

    // Announced in the head, so it is not discovered only once the stylesheet
    // has been fetched and parsed. Nothing else on the page refers to it.
    const preload = page.locator(
      'link[rel="preload"][as="image"][href*="wallpaper_desktop"]',
    );
    await expect(preload).toHaveCount(1);
    await expect(preload).toHaveAttribute("media", `(min-width: 768px)`);

    // The tall one is deliberately NOT preloaded: on a phone the stacked
    // window covers the desk, so it would compete for a connection to paint
    // something nobody sees.
    await expect(
      page.locator('link[rel="preload"][href*="wallpaper_mobile"]'),
    ).toHaveCount(0);

    // On a desk, only the wide one is ever asked for: the media query keeps the
    // browser from spending a request on art it will not paint.
    expect(fetched.some((url) => url.includes("wallpaper_desktop"))).toBe(true);
    expect(fetched.some((url) => url.includes("wallpaper_mobile"))).toBe(false);
  });
});
