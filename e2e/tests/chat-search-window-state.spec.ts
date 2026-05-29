import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'srstate'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'srstate') {
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
  prefix = 'srstate',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectSearchCount(chat: ChatPage, current: number, total: number) {
  await expect(chat.searchBarCount).toHaveText(`${current}/${total}`);
}

test.describe('Search window state across tabs', () => {
  test('search closes on channel, PM, and Status switches while preserving last query (S9)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'srsta');
    const bob = await newSignedInUser(browser, 'srstb');
    const channel = uniqueChannel();
    const marker = Date.now();
    const channelNeedle = `search-state-channel-${marker}`;
    const pmNeedle = `search-state-pm-${marker}`;

    try {
      await alice.chat.sendMessage(`/query ${bob.nick}`);
      await alice.chat.expectTabVisible(bob.nick);

      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.expectTabSelected(channel);

      await alice.chat.sendMessage(channelNeedle);
      await alice.chat.expectMessageVisible(channelNeedle);

      await alice.chat.openSearchFromViewMenu();
      await alice.chat.searchBarInput.fill(channelNeedle);
      await expectSearchCount(alice.chat, 1, 1);

      await alice.chat.switchToStatusTab();
      await expect(alice.chat.searchBar).toBeHidden();
      await expect(alice.chat.searchHighlights).toHaveCount(0);

      await alice.chat.switchToTab(channel);
      await alice.chat.openSearchFromViewMenu();
      await expect(alice.chat.searchBarInput).toHaveValue(channelNeedle);
      await expectSearchCount(alice.chat, 1, 1);

      await alice.chat.switchToTab(bob.nick);
      await expect(alice.chat.searchBar).toBeHidden();
      await expect(alice.chat.searchHighlights).toHaveCount(0);

      await alice.chat.openSearchFromViewMenu();
      await alice.chat.searchBarInput.fill(pmNeedle);
      await expectSearchCount(alice.chat, 0, 0);

      await alice.chat.switchToTab(channel);
      await expect(alice.chat.searchBar).toBeHidden();
      await expect(alice.chat.searchHighlights).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
