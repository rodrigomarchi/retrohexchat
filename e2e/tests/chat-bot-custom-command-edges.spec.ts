import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  connect: ConnectPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
  password: string;
};

function uniqueBotName(prefix = 'botcmd'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

function uniqueChannel(prefix = 'botcmd'): string {
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
  await armXssGuard(page);

  return { chat, connect, ctx, page, nick, password };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'botcmd',
  password = 'pass12345',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();
  await armXssGuard(page);

  return { chat, connect, ctx, page, nick, password };
}

async function armXssGuard(page: Page) {
  await page.evaluate(() => {
    (window as Window & { __e2eXss?: string }).__e2eXss = 'clean';
  });
}

async function expectNoScriptRan(page: Page) {
  await page.waitForTimeout(300);
  await expect
    .poll(() =>
      page.evaluate(() => (window as Window & { __e2eXss?: string }).__e2eXss),
    )
    .toBe('clean');
}

async function cleanupBot(admin: TestUser, botName: string, channel: string) {
  await admin.chat.sendMessage(`/bot part ${botName} ${channel}`).catch(() => {});
  await admin.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
}

test.describe('Bot custom command edges', () => {
  test('custom command variables and special characters render correctly and escaped (Y3)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const operator = await newSignedInUser(browser, 'y3op', 'botpass123');
    const botName = uniqueBotName('y3bot');
    const channel = uniqueChannel('y3bot');
    const trigger = `edge${Math.random().toString(36).slice(2, 6)}`;
    const marker = `y3-marker-${Date.now()}`;
    const payload = `<span data-e2e-y3="${marker}">"& ${marker}`;
    const response = `vars {nickname} {channel} ${payload}`;

    try {
      await admin.chat.sendMessage(
        `/admin user role ${operator.nick} server_operator`,
      );
      await admin.chat.expectMessageVisible(
        `${operator.nick} has been set as server_operator.`,
      );
      await operator.chat.disconnect();
      await operator.connect.signIn(operator.nick, operator.password);
      await operator.chat.waitUntilConnected();
      await armXssGuard(operator.page);

      await operator.chat.sendMessage(`/join ${channel}`);
      await operator.chat.expectTabVisible(channel);

      await operator.chat.sendMessage(`/bot create ${botName} E2E bot ${botName}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' created successfully.`,
      );
      await operator.chat.sendMessage(`/bot join ${botName} ${channel}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' joined ${channel}.`,
      );

      await operator.chat.sendMessage(
        `/bot addcmd ${botName} ${trigger} ${response}`,
      );
      await operator.chat.expectMessageVisible(
        `[BotService] Command '${trigger}' set for ${botName}.`,
      );

      await operator.chat.sendMessage(`!${trigger}`);
      const row = operator.chat.messageRows.filter({ hasText: marker }).last();
      await expect(row).toBeVisible({ timeout: 10_000 });
      await expect(row).toContainText(operator.nick);
      await expect(row).toContainText(channel);
      await expect(row).toContainText('<span');
      await expect(row.locator(`[data-e2e-y3="${marker}"]`)).toHaveCount(0);
      await expect(row.locator('script')).toHaveCount(0);
      await expectNoScriptRan(operator.page);
    } finally {
      await cleanupBot(operator, botName, channel);
      await admin.chat.sendMessage(`/admin user role ${operator.nick} user`);
      await admin.ctx.close();
      await operator.ctx.close();
    }
  });
});
