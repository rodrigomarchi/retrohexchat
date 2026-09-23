/**
 * @section P - Persistence, Reconnect, History, No-Focus-Steal
 * @flow P20 [done] Reading, leaving, receiving and coming back draws the new-messages rule in the right place
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

function uniqueChannel(prefix = "unrd"): string {
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

test.describe("Where you left off", () => {
  test.setTimeout(60_000);

  test("the new-messages rule marks what arrived while you were away (P20)", async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const elsewhere = uniqueChannel("else");
    const alice = await newSignedInUser(browser, "unra");
    const bob = await newSignedInUser(browser, "unrb");
    const read = `read-me-${Date.now()}`;
    const unread = `new-while-away-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);

      await bob.chat.switchToTab(channel);
      await bob.chat.sendMessage(read);
      await alice.chat.expectMessageVisible(read);

      // Nothing is new while you are sitting in the conversation, so no rule.
      await expect(alice.chat.page.getByTestId("unread-divider")).toHaveCount(
        0,
      );

      // Leaving is what settles where you had got to.
      await alice.chat.sendMessage(`/join ${elsewhere}`);
      await alice.chat.expectTabVisible(elsewhere);

      await bob.chat.sendMessage(unread);

      await alice.chat.switchToTab(channel);
      await alice.chat.expectMessageVisible(unread);

      const divider = alice.chat.page.getByTestId("unread-divider");
      await expect(divider).toHaveCount(1);

      // On the line that arrived while away, not on the one already read.
      await expect(
        alice.chat.messageRowByText(unread).getByTestId("unread-divider"),
      ).toBeVisible();
      await expect(
        alice.chat.messageRowByText(read).getByTestId("unread-divider"),
      ).toHaveCount(0);

      await expect(
        alice.chat.page.getByTestId("conversation-toolbar-first-unread"),
      ).toBeVisible();

      await shot(alice.chat.messageList, "unread-divider");
    } finally {
      await Promise.all([alice.ctx.close(), bob.ctx.close()]);
    }
  });
});
