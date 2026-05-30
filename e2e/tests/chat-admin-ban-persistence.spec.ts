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
  prefix = 'admban',
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

test.describe('Admin ban persistence', () => {
  test('server ban blocks reconnect until admin unban restores access (X12)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'x12ban', 'banpass123');
    const offline = await newSignedInUser(browser, 'x12banoff', 'banpass123');
    const reason = `x12-ban-${Date.now()}`;

    try {
      await offline.page.close();

      await admin.chat.sendMessage(
        `/admin user ban ${target.nick} --reason ${reason}`,
      );
      await admin.chat.expectMessageVisible(
        `${target.nick} has been server-banned permanently.`,
      );

      await expect(target.page).toHaveURL(/\/connect\?reason=/);
      await expect(target.page.getByTestId('session-alert')).toContainText(
        'Server banned',
      );

      await admin.chat.sendMessage(
        `/admin user ban ${offline.nick} --reason ${reason}-offline`,
      );
      await admin.chat.expectMessageVisible(
        `${offline.nick} has been server-banned permanently.`,
      );

      const offlinePage = await offline.ctx.newPage();
      offline.page = offlinePage;
      offline.connect = new ConnectPage(offlinePage);
      offline.chat = new ChatPage(offlinePage);

      await offline.page.goto('/chat');
      await expect(offline.page).toHaveURL(/\/connect\?reason=/);
      await expect(offline.page.getByTestId('session-alert')).toContainText(
        'Server banned',
      );

      await target.connect.open();
      await target.connect.signIn(target.nick, target.password);
      await expect(target.page).toHaveURL(/\/connect\?reason=/);
      await expect(target.page.getByTestId('session-alert')).toContainText(
        'Server banned',
      );

      await admin.chat.sendMessage(`/admin user unban ${target.nick}`);
      await admin.chat.expectMessageVisible(
        `${target.nick} has been unbanned from the server.`,
      );

      await target.connect.open();
      await target.connect.signIn(target.nick, target.password);
      await target.chat.waitUntilConnected();
      await expect(target.page).toHaveURL(/\/chat$/);
    } finally {
      await admin.chat.sendMessage(`/admin user unban ${target.nick}`);
      await admin.chat.sendMessage(`/admin user unban ${offline.nick}`);
      await closeUsers([admin, target, offline]);
    }
  });
});
