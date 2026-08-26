/**
 * @section W - Presence, Identity, Nick Changes, Whois/Whowas
 * @flow W12 [done] A private conversation shows the same user list as a channel, listing both participants with the peer first (features P1)
 * @flow W13 [done] The peer's away state reaches a private conversation's user list with no channel in common (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe("Private conversation user list", () => {
  test("a private conversation lists both participants, the peer first (W12)", async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, "w12a");
    const bob = await newSignedInUser(browser, "w12b");

    try {
      await alice.chat.sendMessage(`/msg ${bob.nick} hello there`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);

      // The same sidebar a channel has, now describing the conversation on
      // screen rather than whatever channel was open before it.
      await expect(alice.chat.nicklist).toBeVisible();
      await alice.chat.expectNickInList(bob.nick);
      await alice.chat.expectNickInList(alice.nick);
      await alice.chat.expectNickStatus(bob.nick, "online");
      await expect(alice.chat.nicklist).toContainText("Participants");

      const nicks = await alice.chat.nicklist
        .locator("[data-nick]")
        .evaluateAll((rows) =>
          rows.map((row) => row.getAttribute("data-nick")),
        );
      expect(nicks).toEqual([bob.nick, alice.nick]);

      // Right-click offers the user actions and none of the channel moderation
      // ones: there is no channel here to be an operator of.
      await alice.chat.openNicklistContextMenu(bob.nick);
      await expect(alice.chat.nicklistContextQueryMenuItem).toBeVisible();
      await expect(alice.chat.nicklistContextWhoisMenuItem).toBeVisible();
      await expect(alice.chat.nicklistContextOpMenuItem).toHaveCount(0);
      await expect(alice.chat.nicklistContextVoiceMenuItem).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("away reaches a private conversation's user list with no shared channel (W13)", async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, "w13a");
    const bob = await newSignedInUser(browser, "w13b");
    const away = `away-pm-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/msg ${bob.nick} ping`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectNickStatus(bob.nick, "online");

      // Leaving the default channel takes away the one topic the two of them
      // had in common, so nothing channel-shaped can carry this: the
      // server-wide presence topic is the only route left.
      await bob.chat.sendMessage("/part #lobby");
      await bob.chat.sendMessage(`/away ${away}`);
      await bob.chat.expectMessageVisible(`You are now away: ${away}`);

      await alice.chat.expectNickStatus(bob.nick, "away");

      await bob.chat.sendMessage("/away");
      await bob.chat.expectMessageVisible("You are no longer away");
      await alice.chat.expectNickStatus(bob.nick, "online");
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
