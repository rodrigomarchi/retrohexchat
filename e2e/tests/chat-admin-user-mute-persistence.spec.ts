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

async function newSignedInUser(
  browser: Browser,
  prefix = 'admmute',
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

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Admin mute persistence', () => {
  test('server mute survives reconnect until admin unmute restores sending (X13)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'x13mute', 'mutepass123');
    const blockedText = `x13-muted-${Date.now()}`;
    const restoredText = `x13-unmuted-${Date.now()}`;

    try {
      await admin.chat.sendMessage(`/admin user mute ${target.nick}`);
      await admin.chat.expectMessageVisible(
        `${target.nick} has been muted permanently.`,
      );
      await target.chat.expectMessageVisible(
        'You have been muted by an administrator',
      );

      await target.chat.disconnect();
      await target.connect.signIn(target.nick, target.password);
      await target.chat.waitUntilConnected();

      await target.chat.sendMessage(blockedText);
      await target.chat.expectMessageVisible(
        'You are muted by an administrator',
      );
      await target.chat.expectMessageHidden(blockedText);

      await admin.chat.sendMessage(`/admin user unmute ${target.nick}`);
      await admin.chat.expectMessageVisible(`${target.nick} has been unmuted.`);
      await target.chat.expectMessageVisible(
        'You have been unmuted by an administrator.',
      );

      await target.chat.sendMessage(restoredText);
      await target.chat.expectMessageVisible(restoredText);
    } finally {
      await admin.chat.sendMessage(`/admin user unmute ${target.nick}`);
      await closeUsers([admin, target]);
    }
  });
});
