import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'whowasedge') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'whowasedge',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function signedInAdmin(browser: Browser): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn('TestAdmin', 'adminpass1');
  await chat.waitUntilConnected();

  return { chat, ctx, nick: 'TestAdmin' };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function latestTextSince(chat: ChatPage, start: number): Promise<string> {
  await expect
    .poll(async () => chat.messageRows.count())
    .toBeGreaterThan(start);

  return chat.messageRows.evaluateAll(
    (rows, firstNewRow) =>
      rows
        .slice(firstNewRow)
        .map((row) => row.textContent || '')
        .join('\n'),
    start,
  );
}

test.describe('Whowas edge cases', () => {
  test('/whowas for an online user points to /whois for current info (W5)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'w5a');
    const bob = await newSignedInUser(browser, 'w5b');

    try {
      await alice.chat.sendMessage(`/whowas ${bob.nick}`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is online. Use /whois ${bob.nick} for current info.`,
      );
      await alice.chat.expectMessageHidden(`----- Whowas: ${bob.nick} -----`);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/whowas records expire after configured retention (W6)', async ({
    browser,
  }) => {
    const admin = await signedInAdmin(browser);
    const target = await newSignedInUser(browser, 'w6t');

    try {
      await admin.chat.sendMessage(
        '/admin server set whowas_retention_seconds 5',
      );
      await admin.chat.expectMessageVisible(
        "Server setting 'whowas_retention_seconds' set to '5'.",
      );

      await target.chat.disconnect();

      await admin.chat.sendMessage(`/whowas ${target.nick}`);
      await admin.chat.expectMessageVisible(
        `----- Whowas: ${target.nick} -----`,
      );
      await admin.chat.expectMessageVisible('Last seen:');

      await admin.chat.page.waitForTimeout(6_000);

      const beforeExpiredLookup = await admin.chat.messageRows.count();
      await admin.chat.sendMessage(`/whowas ${target.nick}`);
      const expiredText = await latestTextSince(
        admin.chat,
        beforeExpiredLookup,
      );

      expect(expiredText).toContain(
        `* No whowas information available for ${target.nick}.`,
      );
      expect(expiredText).not.toContain(`----- Whowas: ${target.nick} -----`);
    } finally {
      await admin.chat
        .sendMessage('/admin server set whowas_retention_seconds 3600')
        .catch(() => undefined);
      await closeUsers([admin, target]);
    }
  });
});
