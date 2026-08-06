/**
 * @section Backlog W - Presence, Identity, Nick Changes, Whois/Whowas
 * @flow W4 [done] NickServ register/drop changes are reflected by another user's `/whois Registered:` output without reconnect (features P2)
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

function uniqueChannel(prefix = "nswhois"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = "nswhois") {
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
  prefix = "nswhois",
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe("NickServ whois realtime state", () => {
  test("registering and dropping NickServ state updates another user whois without reconnect (W4)", async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, "w4a");
    const bob = await newSignedInUser(browser, "w4b");
    const channel = uniqueChannel("nswhois");
    const nick = uniqueNickname("w4nick");
    const password = `pw-${Date.now().toString(36)}`;

    try {
      await alice.chat.sendMessage(`/nick ${nick}`);
      await alice.chat.confirmNickChange();
      await alice.chat.waitUntilConnected();
      await alice.chat.expectNickInList(nick);

      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.expectNickInList(nick);

      await bob.chat.sendMessage(`/whois ${nick}`);
      await bob.chat.expectWhoisCard(nick);
      await bob.chat.expectLookupCardField("Registered", "No");
      await bob.chat.closeLookupResult();

      await alice.chat.sendMessage(`/ns register ${password}`);
      await alice.chat.expectMessageVisible(
        `[NickServ] Nickname ${nick} registered successfully`,
      );

      await bob.chat.sendMessage(`/whois ${nick}`);
      await bob.chat.expectWhoisCard(nick);
      await bob.chat.expectLookupCardField("Registered", "Yes");
      await bob.chat.closeLookupResult();

      await alice.chat.sendMessage(`/ns drop ${password}`);
      await alice.chat.expectMessageVisible(
        `[NickServ] Registration for ${nick} dropped`,
      );

      await bob.chat.sendMessage(`/whois ${nick}`);
      await bob.chat.expectWhoisCard(nick);
      await bob.chat.expectLookupCardField("Registered", "No");
      await bob.chat.closeLookupResult();
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
