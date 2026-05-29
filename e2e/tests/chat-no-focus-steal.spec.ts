import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'focus'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'focus') {
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
  prefix = 'focus',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupTwoUsers(browser: Browser) {
  const alice = await newSignedInUser(browser, 'foca');
  const bob = await newSignedInUser(browser, 'focb');

  return { alice, bob };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Chat no-focus-steal flows', () => {
  test('incoming PM marks unread without switching active tab (P3)', async ({
    browser,
  }) => {
    const { alice, bob } = await setupTwoUsers(browser);
    const pmText = `incoming-pm-no-focus-${Date.now()}`;

    try {
      await bob.chat.switchToTab('#lobby');
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.sendMessage(`/msg ${bob.nick} ${pmText}`);

      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabVisible(alice.nick);
      await expect(bob.chat.tab(alice.nick)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await expect(bob.chat.pmConversationItem(alice.nick)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await expect(bob.chat.pmUnreadBadge(alice.nick)).toHaveText('1');
      await bob.chat.expectMessageHidden(pmText);

      await bob.chat.switchToTab(alice.nick);
      await bob.chat.expectMessageVisible(pmText);
      await expect(bob.chat.tab(alice.nick)).toHaveAttribute(
        'data-unread',
        'false',
      );
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('incoming channel message marks unread without switching active tab (P4)', async ({
    browser,
  }) => {
    const { alice, bob } = await setupTwoUsers(browser);
    const channel = uniqueChannel();
    const channelText = `incoming-channel-no-focus-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);

      await alice.chat.switchToTab(channel);
      await alice.chat.expectNickInList(bob.nick);
      await bob.chat.switchToTab('#lobby');
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.sendMessage(channelText);

      await bob.chat.expectTabSelected('#lobby');
      await expect(bob.chat.tab(channel)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await expect(bob.chat.channelConversationItem(channel)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await expect(bob.chat.channelUnreadBadge(channel)).toHaveText('1');
      await bob.chat.expectMessageHidden(channelText);

      await bob.chat.switchToTab(channel);
      await bob.chat.expectMessageVisible(channelText);
      await expect(bob.chat.tab(channel)).toHaveAttribute(
        'data-unread',
        'false',
      );
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
