/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW1 [done] The home loads the desktop's small first-paint bundle, README.txt on the desk opens in place, and a desktop icon moves to another page without a page load
 * @flow PW2 [done] On a phone a page shows its first window, and the taskbar's group for the page brings any other window of it to the screen
 * @flow PW3 [done] The Start menu reaches every page as windows of the desktop, and closing a page's last window hands the address back to the chat
 * @flow PW19 [done] The public pages declare an installable web app: a linked manifest whose icons and service worker are actually served
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";
import { bringForward, closePage } from "../helpers/siteWindows";

function watchBrowserFailures(page: Page) {
  const failures: string[] = [];

  page.on("pageerror", (error) => failures.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") {
      failures.push(`console error: ${message.text()}`);
    }
  });
  page.on("requestfailed", (request) => {
    const url = request.url();
    if (url.includes("/assets/")) {
      failures.push(
        `request failed: ${url} ${request.failure()?.errorText ?? ""}`,
      );
    }
  });
  page.on("response", (response) => {
    const url = response.url();
    if (url.includes("/assets/") && response.status() >= 400) {
      failures.push(`asset response ${response.status()}: ${url}`);
    }
  });

  return failures;
}

test.describe("Landing public pages", () => {
  test("loads the desktop bundle and moves between pages without a reload (PW1)", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/");
    await expect(page.locator('script[src*="/assets/js/desktop"]')).toHaveCount(
      1,
    );
    await expect(page.locator('script[src*="/assets/js/app.js"]')).toHaveCount(
      0,
    );
    await expect(page.getByTestId("chat-window")).toBeVisible();
    await page.evaluate(() => {
      (window as Window & { __sameDocument?: boolean }).__sameDocument = true;
    });

    // README.txt is a file on the desk: it opens in place, before the chat.
    await expect(page.locator("#readme-popup")).toBeHidden();
    await page.getByTestId("desktop-icon-readme-popup").click();
    await expect(page.locator("#readme-popup")).toBeVisible();
    await expect(page.locator("#readme-popup")).toHaveAttribute(
      "aria-hidden",
      "false",
    );

    await page.keyboard.press("Escape");
    await expect(page.locator("#readme-popup")).toBeHidden();

    // The first double-click on a page's icon is not lost to the chat starting.
    await page.getByTestId("desktop-icon-page-features").dblclick();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator("#features-heading")).toBeVisible();
    expect(
      await page.evaluate(
        () => (window as Window & { __sameDocument?: boolean }).__sameDocument,
      ),
    ).toBe(true);

    expect(failures).toEqual([]);
  });

  // A phone shows one window at a time: a page opens on its first, and the
  // taskbar's group for the page reaches the rest.
  test("on a phone a page shows its first window, the taskbar the rest (PW2)", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/features");

    const intro = page.getByTestId("site-window-intro");
    const channels = page.getByTestId("site-window-channels");
    await expect(intro).toBeVisible();
    await expect(channels).toBeHidden();
    await shot(page, "landing-mobile");

    await page.getByTestId("taskbar-group-site").click();
    await page
      .locator(
        '[data-taskbar-group-panel] [data-window-taskbar="site-channels"]',
      )
      .click();
    await expect(channels).toBeVisible();
    await expect(intro).toBeHidden();
    await shot(page, "landing-mobile-second-window");

    expect(failures).toEqual([]);
  });

  test("the Start menu reaches every page, and closing one goes back to the chat (PW3)", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/features");
    await expect(page.locator("[data-window-manager]")).toHaveCount(1);

    const startMenu = page.locator("#chat-start-menu");
    await expect(startMenu).toBeHidden();
    await page.locator("[data-window-start]").click();
    await expect(startMenu).toBeVisible();
    await shot(startMenu, "start-menu-root");

    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Navigate" })
      .hover();
    // A page of the site, reached as a window of the same desktop.
    const faq = startMenu.locator('a[href="/faq"]');
    await expect(faq).toHaveAttribute("data-phx-link", "patch");
    await faq.click();
    await expect(page).toHaveURL(/\/faq$/);
    await expect(page.locator("#faq-heading")).toBeVisible();

    // Closing the page's last window hands the address to the chat behind it.
    await page.waitForFunction(
      () => document.documentElement.dataset.liveBoot === "ready",
      undefined,
      { timeout: 15_000 },
    );
    await closePage(page);
    await expect(page.getByTestId("site-windows")).toHaveCount(0);
    await expect(page).toHaveURL(/\/c\/lobby$/);
    await shot(page, "page-closed-chat-in-front");

    expect(failures).toEqual([]);
  });

  test("the public pages offer an installable app (PW19)", async ({ page }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/how-it-works");

    // A manifest reachable at its URL but linked from no page installs nothing.
    const href = await page
      .locator('link[rel="manifest"]')
      .first()
      .getAttribute("href");
    expect(href).toBeTruthy();

    const manifestResponse = await page.request.get(href as string);
    expect(manifestResponse.status()).toBe(200);
    const manifest = await manifestResponse.json();
    expect(manifest.start_url).toBe("/");
    expect(manifest.display).toBe("standalone");

    // Every icon the manifest names has to exist, or the install prompt is
    // offered against a broken picture.
    for (const icon of manifest.icons) {
      const iconResponse = await page.request.get(icon.src);
      expect(iconResponse.status(), `${icon.src} should be served`).toBe(200);
    }

    const worker = await page.request.get("/sw.js");
    expect(worker.status()).toBe(200);

    // The page that offers the install says how: its own window, reached
    // from the page's taskbar group like any other.
    await bringForward(page, "site-install-app");
    await expect(page.getByTestId("site-window-install-app")).toContainText(
      "Add to Home Screen",
    );
    await shot(page, "landing-installable");

    expect(failures).toEqual([]);
  });
});
