import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
  page: Page;
};

async function signedInUser(page: Page, prefix = 'aa1') {
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
  prefix = 'aa1',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick, page };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function openMutualPm(alice: TestUser, bob: TestUser) {
  await alice.chat.sendMessage(`/query ${bob.nick}`);
  await alice.chat.expectTabSelected(bob.nick);

  await bob.chat.sendMessage(`/query ${alice.nick}`);
  await bob.chat.expectTabSelected(alice.nick);
}

test.describe('Reconnect window state', () => {
  test('browser offline/online preserves active PM, draft, unread PM, and typing indicator (AA1)', async ({
    browser,
  }) => {
    test.setTimeout(45_000);

    const alice = await newSignedInUser(browser, 'aa1a');
    const bob = await newSignedInUser(browser, 'aa1b');
    const carol = await newSignedInUser(browser, 'aa1c');
    const draft = `aa1 draft ${Date.now()}`;
    const unreadMessage = `aa1 unread ${Date.now()}`;

    try {
      await openMutualPm(alice, bob);

      await carol.chat.sendMessage(`/msg ${alice.nick} ${unreadMessage}`);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectTabVisible(carol.nick);
      await expect(alice.chat.tab(carol.nick)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await expect(alice.chat.pmUnreadBadge(carol.nick)).toHaveText('1');

      await alice.chat.chatInput.fill(draft);
      await expect(bob.chat.typingIndicator).toHaveText(
        `${alice.nick} is typing...`,
      );

      await alice.ctx.setOffline(true);
      await expect(alice.chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 5_000 },
      );
      await expect(alice.chat.chatInput).toBeDisabled();
      await expect(alice.chat.chatInput).toHaveValue(draft);
      await alice.chat.expectTabSelected(bob.nick);
      await expect(alice.chat.tab(carol.nick)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await expect(bob.chat.typingIndicator).toHaveText(
        `${alice.nick} is typing...`,
      );

      await alice.ctx.setOffline(false);
      await expect(alice.chat.connectionBanner).toContainText('Reconectado', {
        timeout: 15_000,
      });
      await alice.chat.waitUntilConnected();

      await alice.chat.expectTabSelected(bob.nick);
      await expect(alice.chat.chatInput).toBeEnabled();
      await expect(alice.chat.chatInput).toHaveValue(draft);
      await expect(alice.chat.tab(carol.nick)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await expect(alice.chat.pmUnreadBadge(carol.nick)).toHaveText('1');
      await expect(bob.chat.typingIndicator).toHaveText(
        `${alice.nick} is typing...`,
      );

      await alice.chat.chatInput.press('Enter');
      await bob.chat.expectMessageVisible(draft);
      await expect(bob.chat.typingIndicator).toHaveCount(0);
    } finally {
      await alice.ctx.setOffline(false).catch(() => {});
      await closeUsers([alice, bob, carol]);
    }
  });
});
