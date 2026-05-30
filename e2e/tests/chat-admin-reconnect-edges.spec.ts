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
  prefix = 'aa5',
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

async function takeBrowserOffline(user: TestUser) {
  await user.ctx.setOffline(true);
  await expect(user.chat.connectionBanner).toHaveClass(
    /connection-banner--visible/,
    { timeout: 5_000 },
  );
}

test.describe('Admin reconnect edges', () => {
  test('kick while target browser is offline redirects on reconnect but allows later login (AA5)', async ({
    browser,
  }) => {
    test.setTimeout(60_000);

    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'aa5kick', 'kickpass123');
    const reason = `aa5-kick-${Date.now()}`;
    const afterLogin = `aa5 kick relogin ${Date.now()}`;

    try {
      await takeBrowserOffline(target);

      await admin.chat.sendMessage(
        `/admin user kick ${target.nick} --reason ${reason}`,
      );
      await admin.chat.expectMessageVisible(
        `${target.nick} has been kicked from the server.`,
      );

      await target.ctx.setOffline(false);
      await expect(target.page).toHaveURL(/\/connect\?reason=/, {
        timeout: 15_000,
      });
      await expect(target.page.getByTestId('session-alert')).toContainText(
        reason,
      );

      await target.connect.signIn(target.nick, target.password);
      await target.chat.waitUntilConnected();
      await target.chat.sendMessage(afterLogin);
      await target.chat.expectMessageVisible(afterLogin);
    } finally {
      await target.ctx.setOffline(false).catch(() => {});
      await closeUsers([admin, target]);
    }
  });

  test('ban while target browser is offline blocks reconnect until unban (AA5)', async ({
    browser,
  }) => {
    test.setTimeout(60_000);

    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'aa5ban', 'banpass123');
    const reason = `aa5-ban-${Date.now()}`;

    try {
      await takeBrowserOffline(target);

      await admin.chat.sendMessage(
        `/admin user ban ${target.nick} --reason ${reason}`,
      );
      await admin.chat.expectMessageVisible(
        `${target.nick} has been server-banned permanently.`,
      );

      await target.ctx.setOffline(false);
      await expect(target.page).toHaveURL(/\/connect\?reason=/, {
        timeout: 15_000,
      });
      await expect(target.page.getByTestId('session-alert')).toContainText(
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
    } finally {
      await target.ctx.setOffline(false).catch(() => {});
      await admin.chat.sendMessage(`/admin user unban ${target.nick}`).catch(() => {});
      await closeUsers([admin, target]);
    }
  });
});
