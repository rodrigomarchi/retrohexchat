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
      page.locator('script[src="/assets/js/public_pages.js"]'),
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

  test("mobile navigation opens and links to app connect flow", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/");

    const menuButton = page.locator('button[aria-controls="mobile-nav"]');
    const mobileNav = page.locator("#mobile-nav");

    await shot(page, "landing-mobile");

    await expect(mobileNav).toBeHidden();
    await menuButton.click();
    await expect(menuButton).toHaveAttribute("aria-expanded", "true");
    await expect(mobileNav).toBeVisible();

    await mobileNav.locator('a[href="/features"]').click();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator("#features-heading")).toBeVisible();

    await page.goto("/");
    await page.locator('a[href="/connect"]').first().click();
    await expect(page).toHaveURL(/\/connect$/);
    await expect(page.locator("#nickname")).toBeVisible();
    await expect(page.locator('script[src="/assets/js/app.js"]')).toHaveCount(
      1,
    );

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
    await page.locator("#landing-start-menu").locator('a[href="/faq"]').click();
    await expect(page).toHaveURL(/\/faq$/);
    await expect(page.locator("#faq-heading")).toBeVisible();

    expect(failures).toEqual([]);
  });
});
