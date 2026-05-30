import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'pmunread') {
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
  prefix = 'pmunread',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Multiple PM unread counters', () => {
  test('simultaneous PM unread counts reset only when each PM is opened (V12)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'v12a');
    const bob = await newSignedInUser(browser, 'v12b');
    const carol = await newSignedInUser(browser, 'v12c');
    const aliceFirst = `alice-first-${Date.now()}`;
    const aliceSecond = `alice-second-${Date.now()}`;
    const carolFirst = `carol-first-${Date.now()}`;

    try {
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.sendMessage(`/msg ${bob.nick} ${aliceFirst}`);
      await carol.chat.sendMessage(`/msg ${bob.nick} ${carolFirst}`);

      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.expectTabVisible(carol.nick);
      await bob.chat.expectTabUnread(alice.nick, true);
      await bob.chat.expectTabUnread(carol.nick, true);
      await bob.chat.expectPmConversationUnread(alice.nick, true);
      await bob.chat.expectPmConversationUnread(carol.nick, true);
      await expect(bob.chat.pmUnreadBadge(alice.nick)).toHaveText('1');
      await expect(bob.chat.pmUnreadBadge(carol.nick)).toHaveText('1');

      await alice.chat.sendMessage(`/msg ${bob.nick} ${aliceSecond}`);
      await expect(bob.chat.pmUnreadBadge(alice.nick)).toHaveText('2');
      await expect(bob.chat.pmUnreadBadge(carol.nick)).toHaveText('1');

      await bob.chat.switchToTab(alice.nick);
      await bob.chat.expectMessageVisible(aliceFirst);
      await bob.chat.expectMessageVisible(aliceSecond);
      await bob.chat.expectTabUnread(alice.nick, false);
      await bob.chat.expectPmConversationUnread(alice.nick, false);
      await expect(bob.chat.pmUnreadBadge(alice.nick)).toHaveCount(0);
      await bob.chat.expectTabUnread(carol.nick, true);
      await bob.chat.expectPmConversationUnread(carol.nick, true);
      await expect(bob.chat.pmUnreadBadge(carol.nick)).toHaveText('1');

      await bob.chat.switchToTab(carol.nick);
      await bob.chat.expectMessageVisible(carolFirst);
      await bob.chat.expectTabUnread(carol.nick, false);
      await bob.chat.expectPmConversationUnread(carol.nick, false);
      await expect(bob.chat.pmUnreadBadge(carol.nick)).toHaveCount(0);
      await bob.chat.expectTabUnread(alice.nick, false);
    } finally {
      await closeUsers([alice, bob, carol]);
    }
  });
});
