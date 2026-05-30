import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'unread'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'unread') {
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
  prefix = 'unread',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Conversation unread actions', () => {
  test('Mark Read clears tab and sidebar unread without switching focus (V4)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('markread');
    const alice = await newSignedInUser(browser, 'v4a');
    const bob = await newSignedInUser(browser, 'v4b');
    const message = `mark-read-no-focus-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.switchToTab('#lobby');
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.sendMessage(message);

      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabUnread(channel, true);
      await bob.chat.expectChannelConversationUnread(channel, true);
      await expect(bob.chat.channelUnreadBadge(channel)).toHaveText('1');
      await bob.chat.expectMessageHidden(message);

      await bob.chat.openConversationContextMenu(channel);
      await expect(bob.chat.conversationsMarkReadMenuItem).toBeVisible();
      await bob.chat.conversationsMarkReadMenuItem.click();

      await expect(bob.chat.conversationsContextMenu).toBeHidden();
      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabUnread(channel, false);
      await bob.chat.expectChannelConversationUnread(channel, false);
      await expect(bob.chat.channelUnreadBadge(channel)).toHaveCount(0);
      await bob.chat.expectMessageHidden(message);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
