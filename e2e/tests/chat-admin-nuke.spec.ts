/**
 * @section M - Admin, Server Operations, Bots
 * @flow M12 [done] `/admin nuke` without confirm shows destructive confirmation/help only (features P2)
 * @flow M13 [block] `/admin nuke --confirm` in disposable isolated E2E profile (features P2)
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

test.describe("Admin nuke safety", () => {
  test("/admin nuke without --confirm shows preview and does not execute (M12)", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.sendMessage("/admin nuke");
      await admin.chat.expectMessageVisible("*** NUKE PREVIEW");
      await admin.chat.expectMessageVisible("Preserved:");
    } finally {
      await admin.ctx.close();
    }
  });
});
