/**
 * @section M - Admin, Server Operations, Bots
 * @flow M11 [done] Admin diagnostics render without crashing (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test } from "@playwright/test";
import { ConnectPage } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { adminNick, adminPassword } from "../helpers/env";

const ADMIN_NICK = adminNick();
const ADMIN_PW = adminPassword();

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
};

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

  return { chat, ctx };
}

test.describe("Admin diagnostics", () => {
  test("/admin debug, log, and turn diagnostics render without crashing (M11)", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.sendMessage("/admin debug memory");
      await admin.chat.expectMessageVisible("*** BEAM Memory ***");
      await admin.chat.expectMessageVisible("Total:");

      // These two walk live BEAM structures rather than reading a cached
      // figure, and on a cold node the first of them is comfortably slower
      // than the default five seconds — which is a slow answer, not a missing
      // one, and the retry proved it by passing in under two.
      await admin.chat.sendMessage("/admin debug connections");
      await admin.chat.expectMessageVisible("*** Debug:", 20_000);

      await admin.chat.sendMessage("/admin debug processes");
      await admin.chat.expectMessageVisible("Channel Processes", 20_000);

      await admin.chat.sendMessage("/admin server info");
      await admin.chat.expectMessageVisible("Users online:");

      await admin.chat.sendMessage("/admin log --last 1");
      await admin.chat.expectMessageVisible("*** Audit Log");
      await admin.chat.expectMessageVisible(ADMIN_NICK);

      await admin.chat.sendMessage("/admin turn stats");
      await admin.chat.expectMessageVisible("TURN");
    } finally {
      await admin.ctx.close();
    }
  });
});
