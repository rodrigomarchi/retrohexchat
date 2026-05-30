import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'clip'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'clip') {
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
  prefix = 'clip',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectClipboardText(chat: ChatPage, text: string) {
  await expect
    .poll(() => chat.page.evaluate(() => navigator.clipboard.readText()))
    .toBe(text);
}

test.describe('Conversation context clipboard actions', () => {
  test('copy name writes channel and PM targets to the clipboard (V6)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('copy');
    const alice = await newSignedInUser(browser, 'v6a');
    const bob = await newSignedInUser(browser, 'v6b');

    try {
      await bob.ctx.grantPermissions(['clipboard-read', 'clipboard-write'], {
        origin: 'http://localhost:4003',
      });

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);

      await bob.chat.openConversationContextMenu(channel);
      await bob.chat.conversationsCopyNameMenuItem.click();
      await expect(bob.chat.conversationsContextMenu).toBeHidden();
      await expectClipboardText(bob.chat, channel);

      await bob.chat.sendMessage(`/query ${alice.nick}`);
      await bob.chat.expectTabVisible(alice.nick);

      await bob.chat.openPmConversationContextMenu(alice.nick);
      await expect(bob.chat.conversationsCopyNameMenuItem).toContainText(
        'Copy Nickname',
      );
      await bob.chat.conversationsCopyNameMenuItem.click();
      await expect(bob.chat.conversationsContextMenu).toBeHidden();
      await expectClipboardText(bob.chat, alice.nick);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
