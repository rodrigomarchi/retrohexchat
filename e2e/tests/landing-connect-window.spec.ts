/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW15 [done] The landing connect window signs a new nickname into the chat
 * @flow PW16 [done] The landing keeps its LiveSocket off until a reader reaches for the form
 * @flow PW17 [done] A remembered terminal signs back in with one click from the landing
 * @flow PW18 [done] The landing connect window opens fully on screen at every desktop size
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { uniqueNickname } from "../pages/ConnectPage";

const CONNECT_WINDOW = '[data-testid="landing-connect-window"]';

type LiveSocketWindow = Window & {
  liveSocket?: { isConnected(): boolean };
};

function watchAssetFailures(page: Page) {
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

  return failures;
}

test.describe("Landing connect window", () => {
  // The whole point of embedding the island: a reader signs in without ever
  // visiting /connect.
  test("registers a nickname without leaving the landing page", async ({
    page,
  }) => {
    const failures = watchAssetFailures(page);
    const nickname = uniqueNickname("PWLand");

    await page.goto("/");
    await expect(page.locator(CONNECT_WINDOW)).toBeVisible();

    await page.locator(`${CONNECT_WINDOW} #nickname`).fill(nickname);
    await page.locator(`${CONNECT_WINDOW} [data-testid="connect-btn"]`).click();

    // A fresh nickname routes to registration, in place, still on "/".
    const regPassword = page.locator(`${CONNECT_WINDOW} #reg-password`);
    await expect(regPassword).toBeVisible({ timeout: 15000 });
    expect(new URL(page.url()).pathname).toBe("/");

    await regPassword.fill("pw12345");
    await page
      .locator(`${CONNECT_WINDOW} #reg-password-confirm`)
      .fill("pw12345");
    await page
      .locator(`${CONNECT_WINDOW} [data-testid="register-btn"]`)
      .click();

    await expect(page).toHaveURL(/\/chat/, { timeout: 15000 });
    await expect(page.locator(`[data-testid="chat-input-form"]`)).toBeVisible();

    expect(failures).toEqual([]);
  });

  // The public bundle is ~16kb precisely because the LiveSocket is not in it.
  // If this regresses, every reader and crawler starts paying for a socket they
  // never use.
  test("defers the LiveSocket until the reader reaches for the form", async ({
    page,
  }) => {
    await page.goto("/");
    await expect(page.locator(CONNECT_WINDOW)).toBeVisible();

    // Dead-rendered and inert: the window is on screen, no socket behind it.
    await expect(page.locator("html")).toHaveAttribute(
      "data-connect-boot",
      "idle",
    );
    expect(
      await page.evaluate(() =>
        Boolean((window as LiveSocketWindow).liveSocket),
      ),
    ).toBe(false);

    await page.locator(`${CONNECT_WINDOW} #nickname`).click();

    await expect(page.locator("html")).toHaveAttribute(
      "data-connect-boot",
      "ready",
      { timeout: 15000 },
    );
    await expect
      .poll(() =>
        page.evaluate(() =>
          Boolean((window as LiveSocketWindow).liveSocket?.isConnected()),
        ),
      )
      .toBe(true);
  });

  // A returning reader must not lose their first click, so the server marks
  // them for an eager boot instead of waiting for a touch.
  test("signs a remembered terminal back in with one click", async ({
    page,
  }) => {
    const nickname = uniqueNickname("PWRemem");

    // Register once, asking the browser to remember this terminal.
    await page.goto("/");
    await page.locator(`${CONNECT_WINDOW} #nickname`).fill(nickname);
    await page.locator(`${CONNECT_WINDOW} [data-testid="connect-btn"]`).click();
    await expect(page.locator(`${CONNECT_WINDOW} #reg-password`)).toBeVisible({
      timeout: 15000,
    });
    await page.locator(`${CONNECT_WINDOW} #reg-password`).fill("pw12345");
    await page
      .locator(`${CONNECT_WINDOW} #reg-password-confirm`)
      .fill("pw12345");
    await page
      .locator(`${CONNECT_WINDOW} [data-testid="remember-device"]`)
      .check();
    await page
      .locator(`${CONNECT_WINDOW} [data-testid="register-btn"]`)
      .click();
    await expect(page).toHaveURL(/\/chat/, { timeout: 15000 });

    // Leave, then come back to a landing page as a returning reader.
    await page.goto("/chat/session/clear");
    await page.goto("/features");

    const card = page.locator(
      `${CONNECT_WINDOW} [data-testid="remembered-nick-login-${nickname}"]`,
    );
    await expect(card).toBeVisible({ timeout: 15000 });

    // Recognised readers boot during render, so the first click always lands.
    await expect(page.locator("html")).toHaveAttribute(
      "data-connect-boot",
      "ready",
      { timeout: 15000 },
    );

    await card.click();
    await expect(page).toHaveURL(/\/chat/, { timeout: 15000 });
    await expect(page.locator(`[data-testid="chat-input-form"]`)).toBeVisible();
  });
  // It is the front window, so the cascade starts it at the far end of the
  // offsets — the further down the taller it is, and this is the tallest window
  // on the page. What keeps it on the desk is `.desktop-window`'s
  // `max-height: calc(100% - var(--win-y))`, with the body scrolling past that.
  // That only holds while the body stays `overflow-y-auto`, so pin it here.
  const DESKTOP_SIZES = [
    { width: 1280, height: 720 },
    { width: 1440, height: 900 },
    { width: 1512, height: 850 },
    { width: 1999, height: 1120 },
  ];

  for (const size of DESKTOP_SIZES) {
    test(`opens fully on screen at ${size.width}x${size.height}`, async ({
      page,
    }) => {
      await page.setViewportSize(size);
      await page.goto("/");
      await expect(page.locator(CONNECT_WINDOW)).toBeVisible();

      // Measure against the taskbar, not the workspace. The public taskbar is
      // `fixed` and floats over the workspace, which therefore reaches the
      // bottom of the viewport — so comparing with the workspace reports a
      // window that is fully hidden behind the strip as fitting perfectly.
      const overflow = await page.evaluate(() => {
        const win = document.querySelector(
          '[data-testid="landing-connect-window"]',
        ) as HTMLElement;
        const workspace = document.querySelector(
          ".desktop__workspace",
        ) as HTMLElement;
        const taskbar = document.querySelector(
          '[data-testid="landing-taskbar"]',
        ) as HTMLElement;
        const w = win.getBoundingClientRect();
        const ws = workspace.getBoundingClientRect();
        const tb = taskbar.getBoundingClientRect();

        return {
          bottom: Math.round(w.bottom - Math.min(ws.bottom, tb.top)),
          right: Math.round(w.right - ws.right),
          top: Math.round(ws.top - w.top),
          left: Math.round(ws.left - w.left),
        };
      });

      expect(overflow.bottom).toBeLessThanOrEqual(0);
      expect(overflow.right).toBeLessThanOrEqual(0);
      expect(overflow.top).toBeLessThanOrEqual(0);
      expect(overflow.left).toBeLessThanOrEqual(0);

      // The sign-in controls specifically, not just the frame.
      await expect(
        page.locator(`${CONNECT_WINDOW} [data-testid="connect-btn"]`),
      ).toBeInViewport();
    });
  }
});
