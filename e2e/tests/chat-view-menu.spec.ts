import {
  Browser,
  BrowserContext,
  Locator,
  Page,
  test,
  expect,
} from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx?: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'view'): string {
  return `#z${prefix}${Date.now().toString(36)}${Math.random()
    .toString(36)
    .slice(2, 6)}`;
}

async function signedInUser(page: Page, prefix = 'view') {
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
  prefix = 'view',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { ...user, ctx };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx?.close()));
}

async function clickViewItem(chat: ChatPage, item: Locator) {
  await chat.viewMenuTrigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

test.describe('View menu', () => {
  test('toggles shell panels without losing active tab or unread state (T4)', async ({
    browser,
    page,
  }) => {
    const aliceUser = await signedInUser(page, 'viewa');
    const alice: TestUser = { ...aliceUser };
    const bob = await newSignedInUser(browser, 'viewb');
    const channel = uniqueChannel();
    const unread = `view unread ${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await bob.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabSelected(channel);
      await bob.chat.expectTabSelected(channel);

      await alice.chat.switchToTab('#lobby');
      await bob.chat.sendMessage(unread);
      await expect(alice.chat.tab(channel)).toHaveAttribute(
        'data-unread',
        'true',
      );

      await clickViewItem(alice.chat, alice.chat.toggleConversationsMenuItem);
      await expect(alice.chat.page.getByTestId('conversations')).toHaveCount(0);
      await alice.chat.expectTabSelected('#lobby');
      await expect(alice.chat.tab(channel)).toHaveAttribute(
        'data-unread',
        'true',
      );

      await clickViewItem(alice.chat, alice.chat.toggleConversationsMenuItem);
      await expect(alice.chat.page.getByTestId('conversations')).toBeVisible();
      await alice.chat.expectTabSelected('#lobby');

      await clickViewItem(alice.chat, alice.chat.toggleNicklistMenuItem);
      await expect(alice.chat.nicklist).toHaveCount(0);
      await alice.chat.expectTabSelected('#lobby');

      await clickViewItem(alice.chat, alice.chat.toggleNicklistMenuItem);
      await expect(alice.chat.nicklist).toBeVisible();
      await alice.chat.expectTabSelected('#lobby');

      await clickViewItem(alice.chat, alice.chat.channelListMenuItem);
      await expect(alice.chat.channelListDialog).toBeVisible();
      await alice.chat.expectTabSelected('#lobby');
      await expect(alice.chat.tab(channel)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await alice.chat.channelListDialog
        .getByRole('button', { name: 'Close' })
        .last()
        .click();
      await expect(alice.chat.channelListDialog).toBeHidden();

      await clickViewItem(alice.chat, alice.chat.findMenuItem);
      await expect(alice.chat.searchBar).toBeVisible();
      await alice.chat.expectTabSelected('#lobby');
      await expect(alice.chat.tab(channel)).toHaveAttribute(
        'data-unread',
        'true',
      );
      await alice.chat.searchBar.getByRole('button', { name: 'Close' }).click();
      await expect(alice.chat.searchBar).toBeHidden();
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
