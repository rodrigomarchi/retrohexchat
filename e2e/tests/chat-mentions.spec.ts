/**
 * @section P - Persistence, Reconnect, History, No-Focus-Steal
 * @flow P19 [done] A mention made while away is counted, listed in the Mentions window, and leads back to the line
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = "ment"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

test.describe("Mentions", () => {
  test.setTimeout(60_000);

  test("a mention in a channel you are not looking at is counted and listed (P19)", async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const elsewhere = uniqueChannel("else");
    const alice = await newSignedInUser(browser, "mnta");
    const bob = await newSignedInUser(browser, "mntb");
    const line = `hey ${alice.nick} over here`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);

      // Looking somewhere else is the whole point: a mention you are already
      // reading needs no badge and no window.
      await alice.chat.sendMessage(`/join ${elsewhere}`);
      await alice.chat.expectTabVisible(elsewhere);

      await bob.chat.switchToTab(channel);
      await bob.chat.sendMessage(line);

      const badge = alice.chat.page.getByTestId(
        `channel-mention-badge-${channel}`,
      );
      await expect(badge).toBeVisible();
      await expect(badge).toHaveText("@1");

      await shot(alice.chat.conversationsSidebar, "mention-badge-in-sidebar");

      // The tray says the same thing from the other end of the screen.
      await expect(
        alice.chat.page.getByTestId("tray-mention-badge"),
      ).toBeVisible();

      await alice.chat.page.getByTestId("tray-mention-badge").click();
      const window = alice.chat.page.getByTestId("mentions-window");
      await expect(window).toBeVisible();
      await expect(window).toContainText(line);

      await shot(window, "mentions-window");

      // Following the row lands in the conversation the mention was made in.
      await window.locator('[data-testid^="mention-row-"]').first().click();
      await expect(
        alice.chat.page.getByTestId("mentions-window"),
      ).toBeVisible();
      await alice.chat.expectMessageVisible(line);

      // Reading it is what clears the count.
      await expect(badge).toHaveCount(0);
    } finally {
      await Promise.all([alice.ctx.close(), bob.ctx.close()]);
    }
  });
});
