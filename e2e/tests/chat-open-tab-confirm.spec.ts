/**
 * @section O - Chat UI Micro-Journeys
 * @flow O29 [done] A link posted in a channel asks before opening a tab, naming the host and the whole address
 * @flow O30 [done] Cancelling the question opens nothing and leaves the conversation where it was
 * @flow O31 [done] Ctrl-clicking a link skips the question, because it already asked for a tab
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

function uniqueChannel(prefix = "otab"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(browser: Browser): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname("otab");

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
}

/** A channel with one posted link in it, and the anchor that link became. */
async function channelWithLink(user: TestUser, url: string) {
  const channel = uniqueChannel();
  const marker = `otab-${Date.now()}`;

  await user.chat.sendMessage(`/join ${channel}`);
  await user.chat.expectTabVisible(channel);
  await user.chat.switchToTab(channel);
  await user.chat.sendMessage(`${marker} ${url}`);

  const row = user.chat.messageRowByText(marker);
  await expect(row).toBeVisible();

  const link = row.locator(`a.chat-link[data-url="${url}"]`);
  await expect(link).toBeVisible();

  return link;
}

test.describe("Opening a link in a new tab", () => {
  test("a posted link asks first, naming the host and the address (O29)", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser);
    const url = "https://example.com/some/deep/path?q=1";

    try {
      const link = await channelWithLink(user, url);

      await link.click();

      // The question, and the two things it is for: where you are going, and
      // the address that is the only way to tell a disguised link.
      const message = user.page.getByTestId("open-tab-confirm-message");
      await expect(message).toBeVisible();
      await expect(message).toContainText("example.com");
      await expect(user.page.getByTestId("open-tab-confirm-url")).toContainText(
        url,
      );

      // The way out is an anchor with its own event loop, never a scripted
      // `window.open` a blocker would refuse.
      const confirm = user.page.getByTestId("open-tab-confirm-open");
      await expect(confirm).toHaveAttribute("href", url);
      await expect(confirm).toHaveAttribute("target", "_blank");
      await expect(confirm).toHaveAttribute("rel", "noopener");

      const popupPromise = user.page.waitForEvent("popup");
      await confirm.click();
      const opened = await popupPromise;

      expect(new URL(opened.url()).host).toBe("example.com");
      expect(await opened.evaluate(() => window.opener === null)).toBe(true);
    } finally {
      await user.ctx.close();
    }
  });

  test("cancelling opens nothing (O30)", async ({ browser }) => {
    const user = await newSignedInUser(browser);
    const url = "https://example.com/cancelled";

    try {
      const link = await channelWithLink(user, url);
      const pagesBefore = user.ctx.pages().length;

      await link.click();
      await expect(
        user.page.getByTestId("open-tab-confirm-open"),
      ).toBeVisible();
      await user.page.getByTestId("open-tab-confirm-cancel").click();

      // Gone, and nothing opened. The count is the assertion that matters: a
      // dialog that merely closed while a tab appeared behind it would pass an
      // assertion about the dialog alone.
      await expect(
        user.page.getByTestId("open-tab-confirm-open"),
      ).not.toBeVisible();
      expect(user.ctx.pages().length).toBe(pagesBefore);
    } finally {
      await user.ctx.close();
    }
  });

  test("ctrl-click goes straight through (O31)", async ({ browser }) => {
    const user = await newSignedInUser(browser);
    const url = "https://example.com/modified";

    try {
      const link = await channelWithLink(user, url);

      // A reader holding a modifier has already asked for a background tab.
      // Asking them to confirm it would be noise, so the gate stands aside.
      const openedPromise = user.ctx.waitForEvent("page");
      await link.click({ modifiers: ["ControlOrMeta"] });
      const opened = await openedPromise;

      await expect(
        user.page.getByTestId("open-tab-confirm-open"),
      ).not.toBeVisible();

      // A background tab starts on about:blank and navigates a moment later, so
      // reading its URL the instant the event fires reads the blank one.
      await opened.waitForURL(/example\.com/);
    } finally {
      await user.ctx.close();
    }
  });
});
