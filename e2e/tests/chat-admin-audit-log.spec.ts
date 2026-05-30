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
  prefix = 'admaudit',
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

test.describe('Admin audit log', () => {
  test('audit log shows actor, target, action, and reason for admin user ban (X15)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'x15audit', 'auditpass123');
    const reason = `x15-audit-${Date.now()}`;

    try {
      await admin.chat.sendMessage(
        `/admin user ban ${target.nick} --reason ${reason}`,
      );
      await admin.chat.expectMessageVisible(
        `${target.nick} has been server-banned permanently.`,
      );

      await admin.chat.sendMessage(`/admin log --user ${ADMIN_NICK} --last 10`);

      const auditRow = admin.chat.messageRows.filter({ hasText: reason }).last();
      await expect(auditRow).toContainText(ADMIN_NICK);
      await expect(auditRow).toContainText('user.ban');
      await expect(auditRow).toContainText(`user:${target.nick}`);
      await expect(auditRow).toContainText(`reason: ${reason}`);
    } finally {
      await admin.chat.sendMessage(`/admin user unban ${target.nick}`);
      await closeUsers([admin, target]);
    }
  });
});
