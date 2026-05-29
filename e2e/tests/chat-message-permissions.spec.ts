import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'perm'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'perm') {
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
  prefix = 'perm',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'perma');
  const bob = await newSignedInUser(browser, 'permb');

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);

  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);
  await alice.chat.expectNickInList(bob.nick);

  return { alice, bob };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Message permissions', () => {
  test('non-author cannot edit or delete another user channel message (S1)', async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const text = `not-yours-${Date.now()}`;

    try {
      await alice.chat.sendMessage(text);
      await alice.chat.expectMessageVisible(text);
      await bob.chat.expectMessageVisible(text);

      await bob.chat.chatInput.press('ArrowUp');
      await expect(bob.chat.chatInput).toHaveValue('');
      await expect(bob.chat.messageRowByText(text)).toBeVisible();
      await expect(bob.chat.messageRowByText(text)).not.toHaveClass(/editing/);

      await bob.chat.openMessageContextMenu(text);
      await expect(bob.chat.contextReplyMenuItem).toBeVisible();
      await expect(bob.chat.contextDeleteMenuItem).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
