/**
 * @section M - Admin, Server Operations, Bots
 * @flow M23 [done] The Bot Management roster describes each bot, and selecting one drills into it
 * @flow M38 [done] An admin gives a bot a language with /bot set or Bot Management, and its flag is drawn beside its nickname in the user list, the roster and its detail
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";
import { adminNick, adminPassword } from "../helpers/env";

const ADMIN_NICK = adminNick();
const ADMIN_PW = adminPassword();

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
};

function unique(prefix: string): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signInAdmin(browser: Browser): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(ADMIN_NICK, ADMIN_PW);
  await chat.waitUntilConnected();

  return { chat, ctx, page };
}

test.describe.serial("Bot Management window", () => {
  test("the roster describes each bot, and a selection drills into it", async ({
    browser,
  }) => {
    const admin = await signInAdmin(browser);
    const botName = unique("wire");
    const channel = `#${unique("wire")}`;
    const description = "Bearer of advisories";

    try {
      await admin.chat.sendMessage(`/join ${channel}`);
      await admin.chat.expectTabVisible(channel);
      await admin.chat.switchToTab(channel);

      await admin.chat.sendMessage(`/bot create ${botName} ${description}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' created successfully.`,
      );
      await admin.chat.sendMessage(`/bot set ${botName} prefix .`);
      await admin.chat.sendMessage(`/bot join ${botName} ${channel}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' joined ${channel}.`,
      );
      await admin.chat.sendMessage(
        `/bot addcmd ${botName} sources \\c04CISA\\o and Krebs`,
      );

      // Give the bot something to have done, so the event log has a row to show.
      // The tab is re-selected first: this account carries auto-join channels
      // from earlier runs, and one of them arriving late steals the active tab.
      await admin.chat.switchToTab(channel);
      await admin.chat.sendMessage(".sources");
      await admin.chat.expectMessageVisible("CISA and Krebs");

      await admin.chat.openBotManagementFromToolsMenu();

      // ── The roster: what the bot is and where it works, before any click.
      const row = admin.chat.botItem(botName);
      await expect(row).toBeVisible();
      await expect(row).toContainText(description);
      await expect(row).toContainText(channel);
      await expect(row).toContainText("Running");
      await shot(admin.chat.botManagementDialog, "roster");

      // ── The detail replaces the roster.
      await row.click();
      const back = admin.page.getByTestId("bot-back");
      await expect(back).toBeVisible();
      await expect(admin.chat.botList).toHaveCount(0);

      // The bot's own prefix, not the "!" default the old screen always printed.
      await expect(admin.page.getByTestId("bot-prefix")).toHaveText(".");
      await expect(admin.page.getByTestId("bot-uptime")).not.toHaveText("—");
      await shot(admin.chat.botManagementDialog, "detail-general");

      // Every capability names the key the console would take, beside a value
      // that reads as what it is — not a JSON dump printed over its own labels.
      await admin.chat.botManagementDialog
        .getByRole("button", { name: "Capabilities" })
        .click();
      const greeter = admin.page.getByTestId("bot-capability-greeter");
      await expect(greeter).toContainText("greeting_delivery");
      await expect(greeter).toContainText("repeat_window_sec");
      await expect(greeter).toContainText("1h");
      await shot(admin.chat.botManagementDialog, "detail-capabilities");

      // The event log says what happened and where, rather than blank rows.
      await admin.chat.botManagementDialog
        .getByRole("button", { name: "Events" })
        .click();
      const events = admin.page.locator("#bm-events-list .bm-event-row");
      await expect(events.first()).toContainText(channel);
      await shot(admin.chat.botManagementDialog, "detail-events");

      // Configured text renders as colour, never as the digits behind the
      // control byte.
      await admin.chat.botManagementDialog
        .getByRole("button", { name: "Commands" })
        .click();
      const commandsPane = admin.chat.botManagementDialog.locator(
        '.tabs-content[value="commands"]',
      );
      await expect(commandsPane).toContainText(`.${botName} sources`);
      await expect(commandsPane).toContainText("CISA and Krebs");
      await expect(commandsPane).not.toContainText("04CISA");
      await shot(admin.chat.botManagementDialog, "detail-commands");

      // ── Back returns to the roster with the bot still listed.
      await back.click();
      await expect(admin.chat.botList).toHaveCount(1);
      await expect(admin.chat.botItem(botName)).toBeVisible();
    } finally {
      await admin.chat.closeBotManagementDialog().catch(() => {});
      await admin.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
      await admin.chat.sendMessage(`/part ${channel}`).catch(() => {});
      await admin.ctx.close();
    }
  });

  test("a bot's language is drawn as a flag beside its nickname (M38)", async ({
    browser,
  }) => {
    const admin = await signInAdmin(browser);
    const botName = unique("lang");
    const channel = `#${unique("lang")}`;
    const page = admin.page;
    const flag = (scope: Page | ReturnType<Page["locator"]>, locale: string) =>
      scope.locator(`[data-testid="nick-flag"][data-locale="${locale}"]`);

    try {
      await admin.chat.sendMessage(`/join ${channel}`);
      await admin.chat.expectTabVisible(channel);
      await admin.chat.switchToTab(channel);
      await admin.chat.sendMessage(`/bot create ${botName} Speaks Japanese`);
      await admin.chat.sendMessage(`/bot set ${botName} language ja`);
      await admin.chat.sendMessage(`/bot join ${botName} ${channel}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' joined ${channel}.`,
      );

      // The user list draws the bot's flag like anybody's.
      await admin.chat.switchToTab(channel);
      await admin.chat.expectNickInList(botName);
      await expect(flag(admin.chat.nicklistItem(botName), "ja")).toBeVisible();
      await shot(admin.chat.nicklist, "user-list-bot-flag");

      // Bot Management: the roster row, then the detail's Language select.
      await admin.chat.openBotManagementFromToolsMenu();
      const row = admin.chat.botItem(botName);
      await expect(flag(row, "ja")).toBeVisible();
      await row.click();
      const select = page.getByTestId("bot-language-select");
      await expect(select).toBeVisible();
      await shot(
        page.getByTestId("bot-management-window"),
        "bot-detail-language",
      );

      await select.locator(".retro-combo").click();
      await page
        .locator("#bot-language-select-content label[role=option]", {
          hasText: "Português (Brasil)",
        })
        .click();
      await expect(
        flag(page.getByTestId("bot-language-form"), "pt_BR"),
      ).toBeVisible();
      await page.keyboard.press("Escape");

      // The user list follows without a reload.
      await expect(
        flag(admin.chat.nicklistItem(botName), "pt_BR"),
      ).toBeVisible();
      await shot(admin.chat.nicklist, "user-list-bot-flag-changed");
    } finally {
      await admin.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
      await admin.ctx.close();
    }
  });
});
