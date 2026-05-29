import { Browser, BrowserContext, expect, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'idle') {
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
  prefix = 'idle',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function waitForIdleMinute(chat: ChatPage) {
  await chat.page.waitForTimeout(65_000);
}

function latestIdleRow(chat: ChatPage) {
  return chat.messageRows.filter({ hasText: 'Idle for:' }).last();
}

async function expectLatestIdle(chat: ChatPage, text: string) {
  await expect(latestIdleRow(chat)).toContainText(`Idle for: ${text}`);
}

test.describe('Idle tracking', () => {
  test('/whois idle increases with inactivity and resets after command and message (P11)', async ({
    browser,
  }) => {
    test.setTimeout(180_000);

    const alice = await newSignedInUser(browser, 'idla');
    const bob = await newSignedInUser(browser, 'idlb');

    try {
      await alice.chat.expectNickInList(bob.nick);
      await bob.chat.expectNickInList(alice.nick);

      await waitForIdleMinute(bob.chat);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await expectLatestIdle(alice.chat, '1 minute');

      await bob.chat.sendMessage('/help');
      await bob.chat.expectMessageVisible('Available commands:');
      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await expectLatestIdle(alice.chat, 'less than a minute');

      await waitForIdleMinute(bob.chat);

      const message = `idle-reset-message-${Date.now()}`;
      await bob.chat.sendMessage(message);
      await alice.chat.expectMessageVisible(message);
      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await expectLatestIdle(alice.chat, 'less than a minute');
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
