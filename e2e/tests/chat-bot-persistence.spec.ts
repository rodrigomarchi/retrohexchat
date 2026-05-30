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

function uniqueBotName(prefix = 'botpersist'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
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

  return { chat, connect, ctx, page, nick, password };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'botpersist',
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

  return { chat, connect, ctx, page, nick, password };
}

async function openBotDialogAndSelect(user: TestUser, botName: string) {
  await user.chat.sendMessage('/bot');
  await expect(user.chat.botManagementDialog).toBeVisible();
  await user.chat.botItem(botName).click();
}

async function expectBotStatus(user: TestUser, status: 'Enabled' | 'Disabled') {
  await expect(user.chat.botManagementDialog).toContainText('Status:');
  await expect(user.chat.botManagementDialog).toContainText(status);
}

async function cleanupBot(user: TestUser, botName: string) {
  await user.chat.sendMessage(`/bot enable ${botName}`).catch(() => {});
  await user.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
}

test.describe('Bot persistence', () => {
  test('disabled bot state persists across dialog reopen and operator reconnect (Y4)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const operator = await newSignedInUser(browser, 'y4op', 'botpass123');
    const botName = uniqueBotName('y4bot');

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

      await operator.chat.sendMessage(`/bot create ${botName} E2E bot ${botName}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' created successfully.`,
      );

      await openBotDialogAndSelect(operator, botName);
      await expectBotStatus(operator, 'Enabled');
      await operator.chat.closeBotManagementDialog();

      await operator.chat.sendMessage(`/bot disable ${botName}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' disabled.`,
      );

      await openBotDialogAndSelect(operator, botName);
      await expectBotStatus(operator, 'Disabled');
      await operator.chat.closeBotManagementDialog();

      await operator.chat.disconnect();
      await operator.connect.signIn(operator.nick, operator.password);
      await operator.chat.waitUntilConnected();

      await openBotDialogAndSelect(operator, botName);
      await expectBotStatus(operator, 'Disabled');
      await operator.chat.closeBotManagementDialog();
    } finally {
      await cleanupBot(operator, botName);
      await admin.chat.sendMessage(`/admin user role ${operator.nick} user`);
      await admin.ctx.close();
      await operator.ctx.close();
    }
  });
});
