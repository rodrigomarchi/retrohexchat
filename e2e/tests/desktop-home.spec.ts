/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW28 [done] The desktop is the home: a visitor at / gets the live #lobby in front with an icon per page on the desk; a page opens as its group of windows over the chat, cascaded with its first window in front, and closing its last window goes back to the chat
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { shot } from "../helpers/screenshots";
import { bringForward, closePage, expectInFront } from "../helpers/siteWindows";

async function openFresh(page: Page, path: string) {
  await page.addInitScript(() => {
    try {
      window.localStorage.setItem("retro_hex_chat_tips_suppressed", "true");
    } catch {
      /* localStorage unavailable — the tips only overlay, they do not block */
    }
  });
  await page.goto(path);
}

async function chatStarted(page: Page) {
  await page.waitForFunction(
    () => document.documentElement.getAttribute("data-live-boot") === "ready",
    { timeout: 15_000 },
  );
}

async function doubleClickIcon(page: Page, testId: string) {
  await page.getByTestId(testId).dblclick();
}

test("a visitor's home is the chat, every page one icon away (PW28)", async ({
  page,
}) => {
  await openFresh(page, "/");

  // Nothing over the chat: the home's windows are on the desk, closed.
  await expect(page.getByTestId("chat-window")).toBeVisible();
  await expect(
    page.getByTestId("site-window-retro-hex-chat-welcome"),
  ).toBeHidden();
  await expect(page.getByTestId("desktop-icon-page-home")).toBeVisible();
  await expect(page.getByTestId("desktop-icon-page-features")).toBeVisible();
  await shot(page, "home-first-paint");

  await page.mouse.move(10, 10);
  await chatStarted(page);
  await expect(page.getByTestId("visitor-composer-bar")).toBeVisible();
  await expect(page).toHaveURL(/\/$/);
  await shot(page, "home-connected");

  // The Welcome icon opens the home's windows in place, the first in front.
  await doubleClickIcon(page, "desktop-icon-page-home");
  const welcome = page.getByTestId("site-window-retro-hex-chat-welcome");
  await expectInFront(welcome);
  await expect(page.getByTestId("site-window-the-problem")).toBeVisible();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByTestId("taskbar-group-site")).toBeVisible();
  await shot(page, "home-windows");

  // Closing every window of the page puts it away; the chat is in front.
  await closePage(page);
  await expect(welcome).toBeHidden();
  await expect(page.getByTestId("taskbar-group-site")).toHaveCount(0);
  await expect(page).toHaveURL(/\/$/);
});

test("a page opens as its windows over the chat, without a reload (PW28)", async ({
  page,
}) => {
  await openFresh(page, "/");
  await page.mouse.move(10, 10);
  await chatStarted(page);

  // A sentinel on the window survives only if the page never reloads.
  await page.evaluate(
    () => ((window as unknown as { __sentinel: number }).__sentinel = 1),
  );

  await doubleClickIcon(page, "desktop-icon-page-features");
  await expect(page).toHaveURL(/\/features$/);

  // The first window is the one in front; the rest cascade behind it.
  const intro = page.getByTestId("site-window-intro");
  await expectInFront(intro);
  await expect(intro.locator("h1")).toHaveText("Retro Hex Chat Features");
  const channels = page.getByTestId("site-window-channels");
  await expect(channels).toBeVisible();
  await expect(channels).toHaveClass(/desktop-window--blurred/);
  await shot(page, "features-windows");

  // Bringing a window forward keeps the page's address.
  await channels.locator("[data-window-titlebar]").click();
  await expectInFront(channels);
  await expect(page).toHaveURL(/\/features$/);

  // Back to the chat from its taskbar button: the address follows the chat.
  await page
    .locator('.desktop-taskbar__window-button[data-window-taskbar="chat"]')
    .click();
  await expect(page).toHaveURL(/\/c\/lobby$/);

  // The page is still on the desk behind it: one of its windows brings it,
  // and its address, back.
  await bringForward(page, "site-bots");
  await expect(page).toHaveURL(/\/features$/);

  expect(
    await page.evaluate(
      () => (window as unknown as { __sentinel: number }).__sentinel,
    ),
  ).toBe(1);
});

test("a page's address opens it straight away, help and archive as one window (PW28)", async ({
  page,
}) => {
  await openFresh(page, "/features");
  await expect(page.getByTestId("site-window-intro")).toBeVisible();
  await shot(page, "features-first-paint");

  await page.goto("/chat/help");
  await expect(page.getByTestId("document-window-help")).toBeVisible();
  await shot(page, "help");

  await page.goto("/c/lobby");
  await expect(page.getByTestId("chat-window")).toBeVisible();
  await shot(page, "channel");
});

test("on a phone the chat fills the screen, and a page shows its first window (PW28)", async ({
  browser,
}) => {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const page = await ctx.newPage();

  try {
    await openFresh(page, "/");
    await expect(page.getByTestId("chat-window")).toBeVisible();
    await expect(
      page.getByTestId("site-window-retro-hex-chat-welcome"),
    ).toBeHidden();
    await shot(page, "phone-home");

    await page.mouse.move(10, 10);
    await chatStarted(page);
    await expect(page.getByTestId("visitor-composer-bar")).toBeVisible();
    await shot(page, "phone-home-connected");

    await page.goto("/features");
    await expect(page.getByTestId("site-window-intro")).toBeVisible();
    await expect(page.getByTestId("site-window-channels")).toBeHidden();
    await shot(page, "phone-features");
  } finally {
    await ctx.close();
  }
});

// The socket's own URL carries no language; the page's address does. A page
// read in Portuguese stays in Portuguese once the chat behind it starts.
test("a localized page keeps its language once the chat starts (PW28)", async ({
  page,
}) => {
  await openFresh(page, "/pt-BR/features");
  const html = page.locator("html");
  const heading = page.getByTestId("site-window-intro").locator("h1");
  await expect(html).toHaveAttribute("lang", "pt-BR");
  await expect(heading).not.toHaveText("Retro Hex Chat Features");
  const translated = await heading.innerText();

  await page.mouse.click(5, 5);
  await chatStarted(page);
  await expect(page.getByTestId("chat-window")).toBeVisible();
  await expect(html).toHaveAttribute("lang", "pt-BR");
  await expect(heading).toHaveText(translated);

  // Moving within the desktop stays in the reader's language. The page's
  // windows cover the desk's icons, so the Start menu is the way there.
  await page.locator("[data-window-start]").click();
  await page
    .locator('#chat-start-menu [data-testid="start-menu-navigate-submenu"]')
    .hover();
  await page.locator('#chat-start-menu a[href="/pt-BR/faq"]').click();
  await expect(page).toHaveURL(/\/pt-BR\/faq$/);
});
