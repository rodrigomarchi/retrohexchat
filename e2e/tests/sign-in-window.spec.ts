/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW15 [done] From the visitor's bar under the chat, Create an account opens the sign-in window over the chat without a page load, and registering lands in the chat
 * @flow PW16 [done] A page of the site keeps the chat's LiveSocket off for a crawler, which never acts; a reader's starts on the first interaction
 * @flow PW17 [done] A remembered terminal signs back in with one click from the sign-in window
 * @flow PW18 [done] The sign-in window opens fully on screen at every desktop size
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { CHAT_URL } from "../helpers/urls";
import { shot } from "../helpers/screenshots";

const SIGN_IN_WINDOW = '[data-testid="document-window-connect"]';

type SentinelWindow = Window & { __sameDocument?: boolean };

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

async function register(page: Page, nickname: string, remember = false) {
  const win = page.locator(SIGN_IN_WINDOW);
  await win.locator("#nickname").fill(nickname);
  await win.getByTestId("connect-btn").click();

  const regPassword = win.locator("#reg-password");
  await expect(regPassword).toBeVisible({ timeout: 15000 });
  await regPassword.fill("pw12345");
  await win.locator("#reg-password-confirm").fill("pw12345");
  if (remember) await win.getByTestId("remember-device").check();
  await win.getByTestId("register-btn").click();
}

test.describe("The sign-in window", () => {
  test("opens from the visitor's bar without a page load and signs a nickname in (PW15)", async ({
    page,
  }) => {
    const failures = watchAssetFailures(page);

    await page.goto("/");
    await page.evaluate(() => {
      (window as SentinelWindow).__sameDocument = true;
    });

    await page.mouse.move(10, 10);
    await page.getByTestId("visitor-composer").click({ timeout: 15000 });
    await expect(page.locator(SIGN_IN_WINDOW)).toBeVisible({ timeout: 15000 });
    await expect(page).toHaveURL(/\/connect\?/);
    // A patch, not a page load: the document the chat was in is still here.
    expect(
      await page.evaluate(() => (window as SentinelWindow).__sameDocument),
    ).toBe(true);
    await shot(page, "sign-in-over-the-chat");

    await register(page, uniqueNickname("PWLand"));

    await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });
    await expect(page.getByTestId("chat-input-form")).toBeVisible();
    expect(failures).toEqual([]);
  });

  test("keeps a crawler on the page and starts a reader's chat when they act (PW16)", async ({
    browser,
  }) => {
    const crawlerCtx = await browser.newContext({
      userAgent:
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
    });
    const crawler = await crawlerCtx.newPage();

    try {
      await crawler.goto("/features");
      await expect(crawler.getByTestId("site-window-intro")).toBeVisible();
      // Long past the idle a reader's page boots at: nothing started.
      await crawler.waitForTimeout(3000);
      await expect(crawler.locator("html")).not.toHaveAttribute(
        "data-live-boot",
        "ready",
      );
      await expect(crawler.getByTestId("chat-boot-loading")).toBeVisible();

      // Somebody acting on the page is a reader, whatever the agent says.
      await crawler.getByTestId("site-window-intro").click();
      await expect(crawler.locator("html")).toHaveAttribute(
        "data-live-boot",
        "ready",
        { timeout: 15000 },
      );
      await expect(crawler.getByTestId("chat-boot-loading")).toHaveCount(0, {
        timeout: 15000,
      });
    } finally {
      await crawlerCtx.close();
    }
  });

  test("signs a remembered terminal back in with one click (PW17)", async ({
    page,
  }) => {
    const nickname = uniqueNickname("PWRemem");

    await page.goto("/connect");
    await register(page, nickname, true);
    await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });

    // Leave, then come back to the sign-in window as a returning reader.
    await page.goto("/chat/session/clear");
    await new ConnectPage(page).open();

    const card = page
      .locator(SIGN_IN_WINDOW)
      .getByTestId(`remembered-nick-login-${nickname}`);
    await expect(card).toBeVisible({ timeout: 15000 });
    await shot(page, "remembered-terminal");

    await card.click();
    await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });
    await expect(page.getByTestId("chat-input-form")).toBeVisible();
  });

  // The window manager centres a document window and caps it to the desk, with
  // the body scrolling past that. That only holds while the body stays
  // `overflow-y-auto`, so pin it here.
  const DESKTOP_SIZES = [
    { width: 1280, height: 720 },
    { width: 1440, height: 900 },
    { width: 1512, height: 850 },
    { width: 1999, height: 1120 },
  ];

  for (const size of DESKTOP_SIZES) {
    test(`opens fully on screen at ${size.width}x${size.height} (PW18)`, async ({
      page,
    }) => {
      await page.setViewportSize(size);
      await page.goto("/connect");
      await expect(page.locator(SIGN_IN_WINDOW)).toBeVisible();

      // Measure against the taskbar, not the workspace: the taskbar floats
      // over the workspace, which therefore reaches the bottom of the viewport.
      const overflow = await page.evaluate((selector) => {
        const win = document.querySelector(selector) as HTMLElement;
        const workspace = document.querySelector(
          ".desktop__workspace",
        ) as HTMLElement;
        const taskbar = document.querySelector("#chat-taskbar") as HTMLElement;
        const w = win.getBoundingClientRect();
        const ws = workspace.getBoundingClientRect();
        const tb = taskbar.getBoundingClientRect();

        return {
          bottom: Math.round(w.bottom - Math.min(ws.bottom, tb.top)),
          right: Math.round(w.right - ws.right),
          top: Math.round(ws.top - w.top),
          left: Math.round(ws.left - w.left),
        };
      }, SIGN_IN_WINDOW);

      expect(overflow.bottom).toBeLessThanOrEqual(0);
      expect(overflow.right).toBeLessThanOrEqual(0);
      expect(overflow.top).toBeLessThanOrEqual(0);
      expect(overflow.left).toBeLessThanOrEqual(0);

      await expect(
        page.locator(SIGN_IN_WINDOW).getByTestId("connect-btn"),
      ).toBeInViewport();
    });
  }
});
