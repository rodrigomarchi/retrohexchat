/**
 * @section P - Persistence, Reconnect, History, No-Focus-Steal
 * @flow P1 [done] Registered PM partners restore on reconnect ordered by recency (features P0)
 * @flow P2 [done] Guest PM partners do not persist after reconnect (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

type ChatUser = {
  context: BrowserContext;
  page: Page;
  connect: ConnectPage;
  chat: ChatPage;
  nick: string;
  password: string;
};

async function createRegisteredUser(
  browser: Browser,
  prefix: string,
): Promise<ChatUser> {
  const context = await browser.newContext();
  const page = await context.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  const password = "pass12345";

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { context, page, connect, chat, nick, password };
}

/**
 * Asserts `left` is listed above `right` in the conversations sidebar.
 *
 * Signing back in restores the conversations, not the windows: the sidebar is
 * the list of who you have been talking to, and a tab is one you have opened.
 * So recency is read where the list lives, top to bottom.
 */
async function expectPmListedBefore(
  chat: ChatPage,
  left: string,
  right: string,
) {
  const leftItem = chat.pmConversationItem(left);
  const rightItem = chat.pmConversationItem(right);

  await expect(leftItem).toBeVisible();
  await expect(rightItem).toBeVisible();

  const leftBox = await leftItem.boundingBox();
  const rightBox = await rightItem.boundingBox();

  expect(leftBox).not.toBeNull();
  expect(rightBox).not.toBeNull();
  expect(leftBox!.y).toBeLessThan(rightBox!.y);
}

test.describe("Chat persistence", () => {
  test("registered PM partners restore on reconnect ordered by recency (P1)", async ({
    browser,
  }) => {
    const alice = await createRegisteredUser(browser, "pma");
    const bob = await createRegisteredUser(browser, "pmb");
    const carol = await createRegisteredUser(browser, "pmc");

    try {
      const bobMessage = `persist bob ${Date.now()}`;
      const carolMessage = `persist carol ${Date.now()}`;

      await alice.chat.sendMessage(`/msg ${bob.nick} ${bobMessage}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.page.waitForTimeout(100);
      await alice.chat.sendMessage(`/msg ${carol.nick} ${carolMessage}`);
      await alice.chat.expectTabVisible(carol.nick);

      await alice.chat.disconnect();
      await alice.connect.open();
      await alice.connect.enterNickname(alice.nick);
      await alice.connect.authenticateWithPassword(alice.password);
      await alice.chat.waitUntilConnected();

      // Both conversations come back, most recent first…
      await alice.chat.expandConversationSection("pms");
      await expectPmListedBefore(alice.chat, carol.nick, bob.nick);

      // …and opening one from the list brings its history with it, which is
      // what "restored" has to mean for it to be worth anything.
      await alice.chat.pmConversationItem(carol.nick).click();
      await alice.chat.expectTabVisible(carol.nick);
      await alice.chat.expectMessageVisible(carolMessage);

      await alice.chat.pmConversationItem(bob.nick).click();
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectMessageVisible(bobMessage);
    } finally {
      await alice.context.close();
      await bob.context.close();
      await carol.context.close();
    }
  });

  test("guest PM partners do not restore after reconnect (P2)", async ({
    browser,
  }) => {
    const alice = await createRegisteredUser(browser, "pga");
    const bob = await createRegisteredUser(browser, "pgb");

    try {
      const guestNick = uniqueNickname("pgg");
      const guestMessage = `guest pm ${Date.now()}`;

      await alice.chat.sendMessage(`/nick ${guestNick}`);
      await expect(alice.page.getByTestId("nick-change-dialog")).toBeVisible();
      await alice.page.getByTestId("nick-change-confirm").click();
      await alice.chat.waitUntilConnected();
      await expect(alice.chat.nicklistItem(guestNick)).toBeVisible();

      await alice.chat.sendMessage(`/msg ${bob.nick} ${guestMessage}`);
      await alice.chat.expectTabVisible(bob.nick);

      await alice.page.reload();
      await alice.chat.waitUntilConnected();

      // No PM tab is reopened for anybody, so a hidden tab says nothing about
      // guests. What separates them is the conversations list: a registered
      // nickname gets its partners back there (P1), a guest has nowhere for
      // them to have been kept.
      await alice.chat.expectTabHidden(bob.nick);
      await expect(alice.chat.pmConversationItem(bob.nick)).toHaveCount(0);
    } finally {
      await alice.context.close();
      await bob.context.close();
    }
  });
});
