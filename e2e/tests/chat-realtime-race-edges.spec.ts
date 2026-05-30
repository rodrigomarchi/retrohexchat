import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'race'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'race') {
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
  prefix = 'race',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Realtime race edges', () => {
  test('rapid nick change plus channel message leaves no stale old nick tabs or attribution (Y12)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'y12a');
    const bob = await newSignedInUser(browser, 'y12b');
    const channel = uniqueChannel('y12');
    const newAliceNick = uniqueNickname('y12new');
    const marker = `race-after-nick-${Date.now()}`;

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

      await alice.chat.sendMessage(`/nick ${newAliceNick}`);
      await alice.chat.confirmNickChange();
      await alice.chat.waitUntilConnected();
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await alice.chat.sendMessage(marker);

      await bob.chat.expectMessageVisible(marker, 15_000);
      await expect(bob.chat.messageNickByText(marker, newAliceNick)).toBeVisible();
      await expect(bob.chat.messageNickByText(marker, alice.nick)).toHaveCount(0);
      await bob.chat.expectNickInList(newAliceNick);
      await bob.chat.expectNickNotInList(alice.nick);
      await bob.chat.expectTabHidden(alice.nick);
      await bob.chat.expectTabVisible(newAliceNick);
      await expect(bob.chat.pmConversationItem(alice.nick)).toHaveCount(0);
      await expect(bob.chat.pmConversationItem(newAliceNick)).toBeVisible();
      await bob.chat.expectTabSelected(channel);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
