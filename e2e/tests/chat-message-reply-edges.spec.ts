import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'reply'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'reply') {
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
  prefix = 'reply',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupReply(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'rpla');
  const bob = await newSignedInUser(browser, 'rplb');
  const parent = `reply-parent-${Date.now()}`;
  const reply = `reply-child-${Date.now()}`;

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);

  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);
  await alice.chat.expectNickInList(bob.nick);

  await alice.chat.sendMessage(parent);
  await bob.chat.expectMessageVisible(parent);

  await bob.chat.openMessageContextMenu(parent);
  await bob.chat.contextReplyMenuItem.click();
  await expect(bob.chat.replyBar).toBeVisible();
  await bob.chat.sendMessage(reply);
  await bob.chat.expectMessageVisible(reply);
  await alice.chat.expectMessageVisible(reply);

  return { alice, bob, parent, reply };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Reply edge cases', () => {
  test('reply preview updates when the parent message is edited (S3)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('rpledit');
    const { alice, bob, parent, reply } = await setupReply(browser, channel);
    const updatedParent = `reply-parent-updated-${Date.now()}`;

    try {
      const replyBlock = bob.chat.messageRowByText(reply).getByTestId('reply-block');
      await expect(replyBlock).toContainText(parent);

      await alice.chat.chatInput.press('ArrowUp');
      await expect(alice.chat.chatInput).toHaveValue(parent);
      await alice.chat.chatInput.fill(updatedParent);
      await alice.chat.chatInput.press('Enter');

      await alice.chat.expectMessageVisible(updatedParent);
      await bob.chat.expectMessageVisible(updatedParent);
      await expect(replyBlock).toContainText(updatedParent);
      await expect(replyBlock).not.toContainText(parent);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('reply preview shows deleted state when the parent message is deleted (S4)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('rpldel');
    const { alice, bob, parent, reply } = await setupReply(browser, channel);

    try {
      const replyBlock = bob.chat.messageRowByText(reply).getByTestId('reply-block');
      await expect(replyBlock).toContainText(parent);

      await alice.chat.openMessageContextMenu(parent);
      await alice.chat.contextDeleteMenuItem.click();
      await expect(alice.chat.deleteConfirmButton).toBeVisible();
      await alice.chat.deleteConfirmButton.click();

      await expect(alice.chat.messageList.getByTestId('deleted-message')).toBeVisible();
      await expect(bob.chat.messageList.getByTestId('deleted-message')).toBeVisible();
      await expect(replyBlock).toContainText('[message deleted]');
      await expect(replyBlock).not.toContainText(parent);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
