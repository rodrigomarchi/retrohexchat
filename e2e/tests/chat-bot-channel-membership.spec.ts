import { Browser, BrowserContext, Page, test } from '@playwright/test';
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

function uniqueBotName(prefix = 'botmem'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

function uniqueChannel(prefix = 'botmem'): string {
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

  return { chat, connect, ctx, page, nick, password };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'botop',
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

async function cleanupBot(admin: TestUser, botName: string, channels: string[]) {
  for (const channel of channels) {
    await admin.chat.sendMessage(`/bot part ${botName} ${channel}`).catch(() => {});
  }

  await admin.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
}

test.describe('Bot channel membership', () => {
  test('bot join and part across multiple channels updates nicklists and bot info (Y2)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const operator = await newSignedInUser(browser, 'y2op', 'botpass123');
    const botName = uniqueBotName('y2bot');
    const channelA = uniqueChannel('y2a');
    const channelB = uniqueChannel('y2b');

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

      await operator.chat.sendMessage(`/join ${channelA}`);
      await operator.chat.expectTabVisible(channelA);
      await operator.chat.sendMessage(`/join ${channelB}`);
      await operator.chat.expectTabVisible(channelB);

      await operator.chat.sendMessage(`/bot create ${botName} E2E bot ${botName}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' created successfully.`,
      );

      await operator.chat.sendMessage(`/bot join ${botName} ${channelA}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' joined ${channelA}.`,
      );
      await operator.chat.switchToTab(channelA);
      await operator.chat.expectNickInList(botName);

      await operator.chat.sendMessage(`/bot join ${botName} ${channelB}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' joined ${channelB}.`,
      );
      await operator.chat.switchToTab(channelB);
      await operator.chat.expectNickInList(botName);

      await operator.chat.sendMessage(`/bot info ${botName}`);
      await operator.chat.expectMessageVisible(`[BotService] Bot Info: ${botName}`);
      await operator.chat.expectMessageVisible('Channels: 2');

      await operator.chat.sendMessage(`/bot part ${botName} ${channelA}`);
      await operator.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' left ${channelA}.`,
      );
      await operator.chat.switchToTab(channelA);
      await operator.chat.expectNickNotInList(botName);
      await operator.chat.switchToTab(channelB);
      await operator.chat.expectNickInList(botName);

      await operator.chat.sendMessage(`/bot info ${botName}`);
      await operator.chat.expectMessageVisible('Channels: 1');
    } finally {
      await cleanupBot(operator, botName, [channelA, channelB]);
      await admin.chat.sendMessage(`/admin user role ${operator.nick} user`);
      await admin.ctx.close();
      await operator.ctx.close();
    }
  });
});
