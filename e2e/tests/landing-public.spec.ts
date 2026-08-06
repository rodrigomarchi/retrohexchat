/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW1 [done] The landing loads the public bundle and enables desktop interactions
 * @flow PW2 [done] Mobile navigation opens and links into the app connect flow
 * @flow PW3 [done] The landing runs the real window manager over a taskbar of links
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
  test("loads public bundle and enables desktop interactions", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/");
    await expect(
      page.locator('script[src*="/assets/js/public_pages"]'),
    ).toHaveCount(1);
    await expect(page.locator("#hero-heading")).toBeVisible();

    // The desktop icons live in the C:\Desktop window, which the cascade puts
    // behind the hero — bring it forward the way anyone would.
    await page
      .locator("#landing-taskbar")
      .locator('[data-window-taskbar="c-desktop"]')
      .click();

    await expect(page.locator("#readme-popup")).toBeHidden();
    await page.locator('[data-show-target="#readme-popup"]').click();
    await expect(page.locator("#readme-popup")).toBeVisible();
    await expect(page.locator("#readme-popup")).toHaveAttribute(
      "aria-hidden",
      "false",
    );

    await page.keyboard.press("Escape");
    await expect(page.locator("#readme-popup")).toBeHidden();
    await expect(page.locator("#readme-popup")).toHaveAttribute(
      "aria-hidden",
      "true",
    );

    await page
      .locator('a[href="/features"]')
      .filter({ hasText: "My Chats" })
      .first()
      .click();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator("#features-heading")).toBeVisible();

    expect(failures).toEqual([]);
  });

  // Navigation on a phone runs through the same icon rail the chat uses — the
  // bespoke hamburger and its #mobile-nav drawer are gone, and with them the
  // last piece of chrome that was the landing's alone. Chrome parity across the
  // shells is shell-chrome-parity.spec.ts; this covers landing navigation.
  test("mobile navigation opens and links to app connect flow", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/");

    const navigate = page.getByTestId("app-mobile-menu-rail-navigate");
    const drawer = page.getByTestId("app-mobile-menu-section-navigate");

    await shot(page, "landing-mobile");

    await expect(drawer).toBeHidden();
    await navigate.click();
    await expect(navigate).toHaveAttribute("aria-expanded", "true");
    await expect(drawer).toBeVisible();

    await drawer.locator('a[href="/features"]').click();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator("#features-heading")).toBeVisible();

    // The way into the app is the Start menu, the same entry every other shell
    // names — not a CTA the landing alone used to carry in its header.
    await page.goto("/");
    await page.locator("[data-window-start]").click();
    // Stacked shell: a group drills down on a deliberate tap. Hover is a
    // pointer affordance and is deliberately inert here, so a finger dragging
    // across the rows cannot swap levels under itself.
    await page
      .locator("#landing-start-menu [data-start-submenu-trigger]")
      .filter({ hasText: "Navigate" })
      .click();
    await page.locator('#landing-start-menu a[href="/connect"]').click();
    await expect(page).toHaveURL(/\/connect$/);
    await expect(page.locator("#nickname")).toBeVisible();
    await expect(page.locator('script[src*="/assets/js/app"]')).toHaveCount(1);

    expect(failures).toEqual([]);
  });
  // The landing taskbar is the app's own, driven by the window manager without
  // LiveView. Its buttons point at other documents, so the manager recognises
  // them as navigation and stays out of the way.
  test("runs the real window manager over a taskbar of links", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/");
    await expect(page.locator("[data-window-manager]")).toHaveCount(1);

    const startMenu = page.locator("#landing-start-menu");
    await expect(startMenu).toBeHidden();
    await page.locator("[data-window-start]").click();
    await expect(startMenu).toBeVisible();
    await shot(startMenu, "start-menu-root");

    // The same menu the chat carries, with the app's own entries grayed out —
    // a visitor can read what RetroHexChat does before connecting to it.
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Tools" })
      .hover();
    const addressBook = startMenu.locator(
      '[data-testid="start-menu-item-address-book"]',
    );
    await expect(addressBook).toBeVisible();
    await expect(addressBook).toBeDisabled();
    // Framed on the page, not the menu: the flyout is `left-full` and escapes
    // the menu's own box, so an element-framed shot would crop it away.
    await shot(page, "start-menu-tools-disabled");

    await page.keyboard.press("Escape");
    await expect(startMenu).toBeHidden();

    // The taskbar now stands for this page's windows.
    const taskbar = page.locator("#landing-taskbar");
    const hero = page.locator('[data-window-id="retro-hex-chat-welcome"]');
    await expect(hero).toBeVisible();
    await shot(page, "landing-desktop");

    await hero.locator('[data-window-control="close"]').click();
    await expect(hero).toBeHidden();

    // Closing takes the taskbar button with it, exactly as Win98 does — so the
    // Start menu is where a closed window has to come back from.
    await expect(
      taskbar.locator('[data-window-taskbar="retro-hex-chat-welcome"]'),
    ).toBeHidden();

    await page.locator("[data-window-start]").click();
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Windows" })
      .hover();
    await startMenu
      .locator('[data-window-open="retro-hex-chat-welcome"]')
      .click();
    await expect(hero).toBeVisible();

    // Reaching another page is the Start menu's job.
    await page.locator("[data-window-start]").click();
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Navigate" })
      .hover();
    await startMenu.locator('a[href="/faq"]').click();
    await expect(page).toHaveURL(/\/faq$/);
    await expect(page.locator("#faq-heading")).toBeVisible();

    expect(failures).toEqual([]);
  });
});
