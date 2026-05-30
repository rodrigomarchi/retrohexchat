import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'nickrt'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'nickrt') {
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
  prefix = 'nickrt',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Realtime nick changes', () => {
  test('remote nick change updates nicklist, PM labels, sidebar, and future attribution (W1)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('nickrt');
    const alice = await newSignedInUser(browser, 'w1a');
    const bob = await newSignedInUser(browser, 'w1b');
    const newAliceNick = uniqueNickname('w1new');
    const channelMessage = `nickrt-channel-${Date.now()}`;
    const pmMessage = `nickrt-pm-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.expectNickInList(alice.nick);

      await bob.chat.sendMessage(`/query ${alice.nick}`);
      await bob.chat.expectTabVisible(alice.nick);
      await expect(bob.chat.pmConversationItem(alice.nick)).toBeVisible();

      await bob.chat.switchToTab(channel);
      await bob.chat.expectTabSelected(channel);

      await alice.chat.sendMessage(`/nick ${newAliceNick}`);
      await alice.chat.confirmNickChange();
      await alice.chat.waitUntilConnected();
      await alice.chat.expectNickInList(newAliceNick);

      await bob.chat.expectMessageVisible(
        `${alice.nick} is now known as ${newAliceNick}`,
        15_000,
      );
      await bob.chat.expectNickInList(newAliceNick);
      await bob.chat.expectNickNotInList(alice.nick);
      await bob.chat.expectTabHidden(alice.nick);
      await bob.chat.expectTabVisible(newAliceNick);
      await expect(bob.chat.pmConversationItem(alice.nick)).toHaveCount(0);
      await expect(bob.chat.pmConversationItem(newAliceNick)).toBeVisible();
      await bob.chat.expectTabSelected(channel);

      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await alice.chat.sendMessage(channelMessage);

      await bob.chat.expectMessageVisible(channelMessage);
      await expect(
        bob.chat.messageNickByText(channelMessage, newAliceNick),
      ).toBeVisible();
      await expect(
        bob.chat.messageNickByText(channelMessage, alice.nick),
      ).toHaveCount(0);

      await alice.chat.sendMessage(`/msg ${bob.nick} ${pmMessage}`);
      await bob.chat.expectTabVisible(newAliceNick);
      await bob.chat.expectTabHidden(alice.nick);
      await expect(bob.chat.pmConversationItem(alice.nick)).toHaveCount(0);
      await expect(bob.chat.pmConversationItem(newAliceNick)).toBeVisible();
      await bob.chat.expectTabUnread(newAliceNick, true);

      await bob.chat.switchToTab(newAliceNick);
      await bob.chat.expectMessageVisible(pmMessage);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
