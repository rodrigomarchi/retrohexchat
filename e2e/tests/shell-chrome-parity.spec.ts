/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW4 [done] The sign-in window and help wear the same phone chrome (one case per window with a menu bar)
 * @flow PW5 [done] A rail button opens the shared drawer on its own section
 * @flow PW6 [done] A page of the site carries no menu bar of its own; Start ▸ Open the app is there and inert on the desktop
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";

// The five desktops are meant to read as one product, and the place that kept
// drifting is the menu bar: the landing pages carried a Connect CTA and a lone
// hamburger while the chat had already moved to an icon rail, and help shipped
// a status bar whose breadcrumb ate the width the rail needed.
//
// It hangs under a window's own title bar on every shell now, the way Win98 had
// it — never in a strip across the desk. Each shell names the window it belongs
// to, and the desk itself must carry no header at all.
//
// These are the public shells with a menu bar — the ones reachable with no
// session, so a single spec can hold them side by side. A page of the site has
// none: its windows are read, and the desk's icons and Start menu reach them. The chat's own mobile chrome is covered by
// chat-mobile-desktop.spec.ts, which needs a logged-in user.
const PHONE = { width: 390, height: 780 };

const SHELLS = [
  {
    name: "connect",
    path: "/connect",
    rail: 2,
    window: "document-window-connect",
  },
  { name: "help", path: "/chat/help", rail: 4, window: "document-window-help" },
];

test.describe("Shell chrome parity", () => {
  test.use({ viewport: PHONE });

  for (const shell of SHELLS) {
    test(`${shell.name} wears the same phone chrome`, async ({ page }) => {
      const failures: string[] = [];
      page.on("pageerror", (error) =>
        failures.push(`pageerror: ${error.message}`),
      );
      page.on("console", (message) => {
        if (message.type() === "error")
          failures.push(`console error: ${message.text()}`);
      });

      await page.goto(shell.path);

      // Under the window's own title bar, and nowhere else on the desk.
      const strip = page
        .getByTestId(shell.window)
        .locator("[data-window-menu]");
      await expect(strip).toBeVisible();
      await expect(
        page.locator(
          "[data-window-menu]:not([data-window-id] [data-window-menu])",
        ),
      ).toHaveCount(0);

      // Below 768px the window manager stamps the stacked class, which is what
      // swaps the textual menu strip for the rail.
      await expect(page.locator(".desktop--stacked")).toHaveCount(1);

      const rail = page
        .getByTestId(shell.window)
        .getByTestId("app-mobile-menu-rail");
      await expect(rail).toBeVisible();
      await expect(rail.locator("button")).toHaveCount(shell.rail);
      await expect(
        page
          .getByTestId(shell.window)
          .locator("[data-menubar-trigger]")
          .first(),
      ).toBeHidden();

      // Every shell ends its taskbar with the tray clock, help and showcase
      // included — they used to have no tray at all. `data-clock` is the one
      // marker all five carry: the app shells tick it with a LiveView hook, the
      // landing with a plain interval, and neither is the other's business.
      await expect(page.locator(".desktop-taskbar [data-clock]")).toHaveText(
        /^\d{2}:\d{2}$/,
      );

      await shot(page, `${shell.name}-phone-chrome`);
      expect(failures).toEqual([]);
    });
  }

  test("a rail button opens the shared drawer on its own section", async ({
    page,
  }) => {
    await page.goto("/chat/help");

    // The page runs this engine before the chat's LiveSocket exists and the
    // hook adopts it after, so a working drawer here is the proof that the two
    // share one implementation rather than two that drifted.
    const site = page.getByTestId("document-window-help");
    const language = site.getByTestId("app-mobile-menu-rail-language");
    await language.click();

    await expect(language).toHaveAttribute("data-active", "true");
    const drawer = site.getByTestId("app-mobile-menu-section-language");
    await expect(drawer).toBeVisible();
    await expect(
      site.getByTestId("app-mobile-menu-section-navigate"),
    ).toBeHidden();
    await shot(page, "help-phone-drawer");

    // The same button puts it away; a different one only swaps the section.
    await site.getByTestId("app-mobile-menu-rail-navigate").click();
    await expect(
      site.getByTestId("app-mobile-menu-section-navigate"),
    ).toBeVisible();
    await expect(drawer).toBeHidden();
  });

  test("a page of the site carries no menu bar of its own", async ({
    page,
  }) => {
    await page.goto("/features");
    await expect(page.getByTestId("site-window-intro")).toBeVisible();

    // A page is read; the desk's icons and the Start menu are its navigation,
    // and signing in is the visitor's bar under the chat. The page's windows
    // are there, and not one of them carries a menu.
    const windows = page.locator('[data-window-group="site"]');
    expect(await windows.count()).toBeGreaterThan(1);
    await expect(windows.locator("[data-window-menu]")).toHaveCount(0);

    // This whole describe runs at a phone viewport, where the menu drills down
    // on a tap — hover is deliberately inert in the stacked shell.
    const startMenu = page.locator("#chat-start-menu");
    await page.locator("[data-window-start]").click();
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Navigate" })
      .click();
    const openTheApp = page.getByTestId("start-menu-item-open-the-app");
    await expect(openTheApp).toBeVisible();
    await expect(openTheApp).toHaveAttribute("aria-disabled", "true");
  });
});
