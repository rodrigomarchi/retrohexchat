/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW28 [done] The desktop is the home: a visitor at / gets the Welcome window over a live #lobby, and every page of the site opens as a document window over the chat without a reload
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { shot } from "../helpers/screenshots";

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

test("a visitor's desktop, page by page (PW28)", async ({ page }) => {
  await openFresh(page, "/");
  await expect(page.getByTestId("document-window-site")).toBeVisible();
  await shot(page, "home-first-paint");

  await page.mouse.move(10, 10);
  await page.waitForFunction(
    () => document.documentElement.getAttribute("data-live-boot") === "ready",
    { timeout: 15_000 },
  );
  await expect(page.getByTestId("chat-window")).toBeVisible();
  await expect(page.getByTestId("welcome-enter-chat")).toBeVisible();
  await shot(page, "home-connected");

  await page.getByTestId("welcome-enter-chat").click();
  await expect(page).toHaveURL(/\/c\/lobby$/);
  await shot(page, "entered-chat");

  await page.goto("/");
  await expect(page.getByTestId("chat-window")).toBeVisible();
  await shot(page, "home-returning-visitor");

  await page.goto("/features");
  await expect(page.getByTestId("document-window-site")).toContainText(
    "Features",
  );
  await shot(page, "features");

  await page.goto("/chat/help");
  await expect(page.getByTestId("document-window-help")).toBeVisible();
  await shot(page, "help");

  await page.goto("/c/lobby");
  await expect(page.getByTestId("chat-window")).toBeVisible();
  await shot(page, "channel");
});

test("the Welcome on a phone fills the screen, with the way in first (PW28)", async ({
  browser,
}) => {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const page = await ctx.newPage();

  try {
    await openFresh(page, "/");
    const welcome = page.getByTestId("document-window-site");
    await expect(welcome).toBeVisible();
    await expect(page.getByTestId("welcome-enter-chat")).toBeInViewport();
    await shot(page, "phone-welcome");

    await page.getByTestId("welcome-enter-chat").click();
    await expect(page).toHaveURL(/\/c\/lobby$/);
    await expect(page.getByTestId("chat-window")).toBeVisible();
    await shot(page, "phone-entered-chat");
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
  const site = page.getByTestId("document-window-site");
  await expect(site).toContainText("Navegar");

  await page.mouse.click(5, 5);
  await page.waitForFunction(
    () => document.documentElement.getAttribute("data-live-boot") === "ready",
    { timeout: 15_000 },
  );
  await expect(page.getByTestId("chat-window")).toBeVisible();
  await expect(site).toContainText("Navegar");
  await expect(site).not.toContainText("Navigate");

  // Moving within the desktop stays in the reader's language.
  const link = site
    .locator('a[data-phx-link="patch"][href^="/pt-BR/"]:visible')
    .first();
  const href = await link.getAttribute("href");
  await link.click();
  await expect(page).toHaveURL(new RegExp(`${href}$`));
  await expect(site).toContainText("Navegar");
});
