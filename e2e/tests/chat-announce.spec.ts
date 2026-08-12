/**
 * @section M - Admin, Server Operations, Bots
 * @flow M18 [done] `/announce` broadcasts to connected users and bypasses ignore (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { adminNick, adminPassword } from "../helpers/env";

const ADMIN_NICK = adminNick();
const ADMIN_PW = adminPassword();

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = "ann",
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

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe("Announcements", () => {
  test("/announce broadcasts to connected users and bypasses ignore filters (M18)", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const alice = await newSignedInUser(browser, "anna");
    const hiddenText = `ignored-admin-message-${Date.now()}`;
    const announcement = `global-announcement-${Date.now()}`;

    try {
      await admin.chat.switchToTab("#lobby");
      await alice.chat.switchToTab("#lobby");
      await alice.chat.expectNickInList(ADMIN_NICK);

      await alice.chat.sendMessage(`/ignore ${ADMIN_NICK} all`);
      await alice.chat.expectMessageVisible(
        `* ${ADMIN_NICK} is now ignored (all)`,
      );

      await admin.chat.sendMessage(hiddenText);
      await alice.chat.expectMessageHidden(hiddenText);

      await admin.chat.sendMessage(`/announce ${announcement}`);
      await admin.chat.expectMessageVisible("Announcement sent to all users.");
      await admin.chat.expectMessageVisible(announcement);
      await alice.chat.expectMessageVisible(announcement);
    } finally {
      await closeUsers([admin, alice]);
    }
  });
});
