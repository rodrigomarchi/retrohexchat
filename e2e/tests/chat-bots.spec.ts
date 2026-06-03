import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

function uniqueChannel(prefix = 'bot'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueBotName(prefix = 'bot'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'bot',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
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

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function cleanupBot(admin: TestUser, botName: string, channel?: string) {
  if (channel) {
    await admin.chat.sendMessage(`/bot part ${botName} ${channel}`).catch(() => {});
  }

  await admin.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
}

async function createBot(admin: TestUser, botName: string) {
  await admin.chat.sendMessage(`/bot create ${botName} E2E bot ${botName}`);
  await admin.chat.expectMessageVisible(
    `[BotService] Bot '${botName}' created successfully.`,
  );
}

async function createBotInChannel(admin: TestUser, botName: string, channel: string) {
  await admin.chat.sendMessage(`/join ${channel}`);
  await admin.chat.expectTabVisible(channel);
  await admin.chat.switchToTab(channel);

  await createBot(admin, botName);
  await admin.chat.sendMessage(`/bot join ${botName} ${channel}`);
  await admin.chat.expectMessageVisible(
    `[BotService] Bot '${botName}' joined ${channel}.`,
  );
}

test.describe.serial('Bot commands', () => {
  test('non-admin /bot lists bots, admin /bot opens management dialog (M14)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'botu');
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await user.chat.sendMessage('/bot');
      await expect(
        user.chat.messageList.getByText('[BotService]', { exact: false }).first(),
      ).toBeVisible();

      await admin.chat.sendMessage('/bot');
      await expect(admin.chat.botManagementDialog).toBeVisible();
      await expect(admin.chat.botManagementDialog).toContainText('Bot Management');
      await expect(admin.chat.botList).toHaveCount(1);
    } finally {
      await closeUsers([user, admin]);
    }
  });

  test('admin creates a bot, joins it to a channel, and sees it in nicklist (M15)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const botName = uniqueBotName('botj');
    const channel = uniqueChannel('botj');

    try {
      await createBotInChannel(admin, botName, channel);
      await admin.chat.expectNickInList(botName);
    } finally {
      await cleanupBot(admin, botName, channel);
      await closeUsers([admin]);
    }
  });

  test('bot custom command add/list/invoke/delete works through slash command (M16)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const botName = uniqueBotName('botc');
    const channel = uniqueChannel('botc');
    const trigger = `ping${Math.random().toString(36).slice(2, 6)}`;
    const response = `bot-response-${Date.now()} {nickname} {channel}`;
    const renderedResponse = response
      .replace('{nickname}', ADMIN_NICK)
      .replace('{channel}', channel);

    try {
      await createBotInChannel(admin, botName, channel);

      await admin.chat.sendMessage(`/bot addcmd ${botName} ${trigger} ${response}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Command '${trigger}' set for ${botName}.`,
      );

      await admin.chat.sendMessage(`/bot commands ${botName}`);
      await admin.chat.expectMessageVisible(`[BotService] Commands for ${botName}:`);
      await admin.chat.expectMessageVisible(trigger);

      await admin.chat.sendMessage(`!${trigger}`);
      await admin.chat.expectMessageVisible(renderedResponse);

      await admin.chat.sendMessage(`/bot delcmd ${botName} ${trigger}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Command '${trigger}' removed from ${botName}.`,
      );

      await admin.chat.sendMessage(`/bot commands ${botName}`);
      await admin.chat.expectMessageVisible(
        `[BotService] ${botName} has no custom commands.`,
      );
    } finally {
      await cleanupBot(admin, botName, channel);
      await closeUsers([admin]);
    }
  });

  test('bot enable/disable/destroy changes response behavior and cleans up bot (M17)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const botName = uniqueBotName('bote');
    const channel = uniqueChannel('bote');
    const mentionResponse = `Hi ${ADMIN_NICK}! Try !help for my commands.`;

    try {
      await createBotInChannel(admin, botName, channel);
      await admin.chat.expectNickInList(botName);

      await admin.chat.sendMessage(`/bot set ${botName} cooldown 500`);
      await admin.chat.expectMessageVisible('[BotService] Cooldown set to 500ms.');

      await admin.chat.sendMessage(`hello ${botName}`);
      await admin.chat.expectMessageVisible(mentionResponse);

      await admin.chat.sendMessage(`/bot disable ${botName}`);
      await admin.chat.expectMessageVisible(`[BotService] Bot '${botName}' disabled.`);

      const mentionResponses = admin.chat.messageList.getByText(mentionResponse, {
        exact: false,
      });
      const responseCountBeforeDisabledMention = await mentionResponses.count();

      await admin.chat.sendMessage(`still there ${botName}`);
      await expect(mentionResponses).toHaveCount(responseCountBeforeDisabledMention, {
        timeout: 1_000,
      });

      await admin.chat.sendMessage(`/bot enable ${botName}`);
      await admin.chat.expectMessageVisible(`[BotService] Bot '${botName}' enabled.`);
      await admin.page.waitForTimeout(600);

      await admin.chat.sendMessage(`back again ${botName}`);
      await admin.chat.expectMessageVisible(mentionResponse);

      await admin.chat.sendMessage(`/bot destroy ${botName}`);
      await admin.chat.expectMessageVisible(`[BotService] Bot '${botName}' destroyed.`);
      await admin.chat.expectNickNotInList(botName);
    } finally {
      await cleanupBot(admin, botName, channel);
      await closeUsers([admin]);
    }
  });
});
