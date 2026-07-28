import { expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";

/**
 * Paging the Trusted Terminals security log through the window.
 *
 * The two lists in this window — live sessions and security events — are the
 * surfaces where a paginated query used to stop at the first page: the domain
 * returned a cursor and the window threw it away. What matters here is that the
 * page after the first one is reachable, and that the list says when it ends.
 *
 * The log is seeded by renaming the terminal, which is the cheapest real action
 * that writes one security event per use.
 */

const EVENTS_PAGE_SIZE = 20;
const RENAMES = 22;

test.describe("Trusted Terminals pagination", () => {
  test("loads the next page of security events and closes the list", async ({
    browser,
  }) => {
    test.setTimeout(180_000);

    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    const nick = uniqueNickname("ttp");

    try {
      await connect.open();
      await connect.enterNickname(nick);

      // Remembering the terminal is what creates the trusted device the window
      // is about; without it there is nothing to list.
      await page.getByTestId("remember-device").check();
      await connect.registerWithPassword("pass12345");
      await chat.waitUntilConnected();

      // Retry the whole open: a LiveView re-render right after connect can
      // re-close the just-opened dropdown (the known first-menu-open flake).
      const menuItem = page
        .getByTestId("context-menu-item-open_trusted_terminals_dialog")
        .filter({ visible: true });

      await expect(async () => {
        await chat.openFileMenu();
        await expect(menuItem).toBeVisible({ timeout: 1000 });
      }).toPass({ timeout: 10_000 });

      await menuItem.click();

      const panel = page.getByTestId("trusted-terminals-panel");
      await expect(panel).toBeVisible();

      const renameForm = panel.locator(
        '[data-testid^="trusted-device-rename-form-"]',
      );
      await expect(renameForm).toBeVisible();

      // Each save writes one `device.renamed` event, so this walks the log past
      // its first page.
      for (let i = 1; i <= RENAMES; i += 1) {
        await renameForm.locator('input[name="label"]').fill(`Terminal ${i}`);
        await renameForm.locator('button[type="submit"]').click();
        await expect(
          page.getByTestId("trusted-terminals-status"),
        ).toContainText(/renamed/i);
      }

      const eventRows = panel.locator('[data-testid^="trusted-event-"]');
      await expect(eventRows).toHaveCount(EVENTS_PAGE_SIZE);

      const loadMore = page.getByTestId("trusted-events-load-more");
      await expect(loadMore).toBeVisible();
      await expect(page.getByTestId("trusted-events-end")).toHaveCount(0);
      await shot(panel, "events-first-page");

      await loadMore.click();

      // The second page lands under the first rather than replacing it.
      await expect
        .poll(async () => eventRows.count(), { timeout: 20_000 })
        .toBeGreaterThan(EVENTS_PAGE_SIZE);

      // Renames plus the account's own setup events fit inside two pages, so
      // the list is exhausted and says so instead of offering another page.
      await expect(page.getByTestId("trusted-events-end")).toBeVisible();
      await expect(loadMore).toHaveCount(0);
      await shot(panel, "events-end-of-list");
    } finally {
      await ctx.close();
    }
  });
});
