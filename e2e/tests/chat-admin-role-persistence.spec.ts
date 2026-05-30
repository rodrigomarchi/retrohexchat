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
  prefix = 'admrole',
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

test.describe('Admin role persistence', () => {
  test('server operator role appears after reconnect and grants operator-only command access (X14)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'x14role', 'rolepass123');
    const beforeMessage = `x14-before-${Date.now()}`;
    const afterMessage = `x14-after-${Date.now()}`;

    try {
      await target.chat.openFileMenu();
      await expect(target.chat.adminConsoleMenuItem).toHaveCount(0);
      await target.page.keyboard.press('Escape');

      await target.chat.sendMessage(`/wallops ${beforeMessage}`);
      await target.chat.expectMessageVisible(
        'Permission denied: you must be a server operator.',
      );

      await admin.chat.sendMessage(
        `/admin user role ${target.nick} server_operator`,
      );
      await admin.chat.expectMessageVisible(
        `${target.nick} has been set as server_operator.`,
      );
      await target.chat.expectMessageVisible(
        'Your server role has been changed to: server_operator',
      );

      await target.chat.disconnect();
      await target.connect.signIn(target.nick, target.password);
      await target.chat.waitUntilConnected();

      await target.chat.openAdminConsoleFromMenu();
      await target.page.keyboard.press('Escape');
      await expect(target.chat.adminConsoleDialog).toBeHidden();

      await target.chat.sendMessage(`/wallops ${afterMessage}`);
      await target.chat.expectMessageVisible('Wallops sent.');
    } finally {
      await admin.chat.sendMessage(`/admin user role ${target.nick} user`);
      await closeUsers([admin, target]);
    }
  });
});
