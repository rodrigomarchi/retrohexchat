/**
 * @section Y - Bot And Automation Edges
 * @flow Y1 [done] Duplicate bot name/nickname creation attempts show field-specific errors and leave one bot list row (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import { ConnectPage } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { adminNick, adminPassword } from "../helpers/env";

const ADMIN_NICK = adminNick();
const ADMIN_PW = adminPassword();

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

function uniqueBotName(prefix = "botedge"): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

function uniqueChannel(prefix = "botedge"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
}

async function cleanupBot(admin: TestUser, botName: string) {
  await admin.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
}

test.describe("Bot edge cases", () => {
  test("duplicate bot name and nickname validation stays clear and leaves one list row (Y1)", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const botName = uniqueBotName("y1bot");
    const secondBotName = uniqueBotName("y1alt");
    const channel = uniqueChannel("y1bot");

    try {
      await admin.chat.sendMessage(`/join ${channel}`);
      await admin.chat.expectTabVisible(channel);
      await admin.chat.switchToTab(channel);

      await admin.chat.sendMessage(`/bot create ${botName} E2E bot ${botName}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' created successfully.`,
      );

      await admin.chat.sendMessage(`/bot create ${botName} duplicate`);
      await admin.chat.expectMessageVisible(
        "[BotService] Failed to create bot: name: has already been taken",
      );

      await admin.chat.sendMessage("/bot");
      await expect(admin.chat.botManagementDialog).toBeVisible();
      await admin.chat.openNewBotDialog();
      await admin.chat.newBotNameInput.fill(secondBotName);
      await admin.chat.newBotNicknameInput.fill(botName);
      await admin.chat.newBotDescriptionInput.fill("Duplicate nickname check");
      await admin.chat.newBotCreateButton.click();

      await admin.chat.expectMessageVisible(
        `[BotService] Failed to create bot '${secondBotName}': nickname: has already been taken`,
      );
      await expect(admin.chat.newBotDialog).toBeVisible();

      await admin.chat.newBotCancelButton.click();
      await expect(admin.chat.newBotDialog).toBeHidden();
      await expect(admin.chat.botItem(botName)).toHaveCount(1);
      await expect(admin.chat.botItem(secondBotName)).toHaveCount(0);
      await admin.chat.closeBotManagementDialog();
    } finally {
      await cleanupBot(admin, secondBotName);
      await cleanupBot(admin, botName);
      await admin.ctx.close();
    }
  });
});
