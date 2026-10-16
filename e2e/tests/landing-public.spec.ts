/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW1 [done] The home loads the desktop's small first-paint bundle, its C:\Desktop section works, and its links move between pages without a page load
 * @flow PW2 [done] On a phone the page's own menu rail opens its drawer on the first tap, even as the chat starts, and leads to another page
 * @flow PW3 [done] The Start menu reaches every page as a window of the desktop, and closing a page hands the address back to the chat
 * @flow PW19 [done] The public pages declare an installable web app: a linked manifest whose icons and service worker are actually served
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";

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
    await expect(page.locator("#hero-heading")).toBeVisible();
    await page.evaluate(() => {
      (window as Window & { __sameDocument?: boolean }).__sameDocument = true;
    });

    // The C:\Desktop section's README opens its popup in place.
    await page.getByTestId("document-contents-c-desktop").click();
    await expect(page.locator("#readme-popup")).toBeHidden();
    await page.locator('[data-show-target="#readme-popup"]').click();
    await expect(page.locator("#readme-popup")).toBeVisible();
    await expect(page.locator("#readme-popup")).toHaveAttribute(
      "aria-hidden",
      "false",
    );

    await page.keyboard.press("Escape");
    await expect(page.locator("#readme-popup")).toBeHidden();

    await page
      .locator('a[href="/features"]:visible')
      .filter({ hasText: "My Chats" })
      .first()
      .click();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator("#features-heading")).toBeVisible();
    expect(
      await page.evaluate(
        () => (window as Window & { __sameDocument?: boolean }).__sameDocument,
      ),
    ).toBe(true);

    expect(failures).toEqual([]);
  });

  // Navigation on a phone runs through the same icon rail the chat uses. The
  // first tap is also what starts the chat, and the menu it opens has to stay
  // open through the re-render that follows.
  test("the phone's menu rail opens on the first tap and leads to another page (PW2)", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/");

    const site = page.getByTestId("document-window-site");
    const navigate = site.getByTestId("app-mobile-menu-rail-navigate");
    const drawer = site.getByTestId("app-mobile-menu-section-navigate");
    await shot(page, "landing-mobile");

    await expect(drawer).toBeHidden();
    await navigate.click();
    await page.waitForFunction(
      () => document.documentElement.dataset.liveBoot === "ready",
      undefined,
      { timeout: 15_000 },
    );
    await expect(navigate).toHaveAttribute("aria-expanded", "true");
    await expect(drawer).toBeVisible();
    await shot(page, "landing-mobile-drawer");

    await drawer.locator('a[href="/features"]').click();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator("#features-heading")).toBeVisible();

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

    // Closing the page window hands the address to the chat behind it.
    const site = page.getByTestId("document-window-site");
    await page.waitForFunction(
      () => document.documentElement.dataset.liveBoot === "ready",
      undefined,
      { timeout: 15_000 },
    );
    await site.locator('[data-window-control="close"]').first().click();
    await expect(site).toHaveCount(0);
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

    await expect(
      page.getByTestId("document-contents-install-app"),
    ).toBeVisible();
    await shot(page, "landing-installable");

    expect(failures).toEqual([]);
  });
});
