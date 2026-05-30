import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'unreadedge'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'unreadedge') {
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
  prefix = 'unreadedge',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Tab unread close/reopen edges', () => {
  test('closing unread channel and PM tabs clears stale unread state before reopen (V9)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('closeunread');
    const channelMessage = `close-unread-channel-${Date.now()}`;
    const pmMessage = `close-unread-pm-${Date.now()}`;
    const alice = await newSignedInUser(browser, 'v9a');
    const bob = await newSignedInUser(browser, 'v9b');

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.switchToTab('#lobby');
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.sendMessage(channelMessage);
      await bob.chat.expectTabUnread(channel, true);
      await bob.chat.expectChannelConversationUnread(channel, true);
      await expect(bob.chat.channelUnreadBadge(channel)).toHaveText('1');

      await bob.chat.closeTab(channel);
      await bob.chat.expectTabHidden(channel);
      await expect(bob.chat.channelConversationItem(channel)).toHaveCount(0);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.expectTabSelected(channel);
      await bob.chat.expectTabUnread(channel, false);
      await bob.chat.expectChannelConversationUnread(channel, false);
      await expect(bob.chat.channelUnreadBadge(channel)).toHaveCount(0);
      await bob.chat.expectMessageVisible(channelMessage);

      await bob.chat.switchToTab('#lobby');
      await alice.chat.sendMessage(`/msg ${bob.nick} ${pmMessage}`);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.expectTabUnread(alice.nick, true);
      await bob.chat.expectPmConversationUnread(alice.nick, true);
      await expect(bob.chat.pmUnreadBadge(alice.nick)).toHaveText('1');

      await bob.chat.closeTab(alice.nick);
      await bob.chat.expectTabHidden(alice.nick);
      await expect(bob.chat.pmConversationItem(alice.nick)).toHaveCount(0);

      await bob.chat.sendMessage(`/query ${alice.nick}`);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.expectTabSelected(alice.nick);
      await bob.chat.expectTabUnread(alice.nick, false);
      await bob.chat.expectPmConversationUnread(alice.nick, false);
      await expect(bob.chat.pmUnreadBadge(alice.nick)).toHaveCount(0);
      await bob.chat.expectMessageVisible(pmMessage);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
