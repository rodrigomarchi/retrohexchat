import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'pma') {
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
  prefix = 'pma',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupPm(browser: Browser) {
  const alice = await newSignedInUser(browser, 'pmaa');
  const bob = await newSignedInUser(browser, 'pmab');
  const parent = `pm-parent-${Date.now()}`;

  await alice.chat.sendMessage(`/msg ${bob.nick} ${parent}`);
  await alice.chat.expectTabVisible(bob.nick);
  await bob.chat.expectTabVisible(alice.nick);
  await alice.chat.switchToTab(bob.nick);
  await bob.chat.switchToTab(alice.nick);
  await alice.chat.expectMessageVisible(parent);
  await bob.chat.expectMessageVisible(parent);

  return { alice, bob, parent };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('PM message actions', () => {
  test('PM messages support reply, edit, delete, and deleted placeholders (S2)', async ({
    browser,
  }) => {
    const { alice, bob, parent } = await setupPm(browser);
    const reply = `pm-reply-${Date.now()}`;
    const updated = `pm-updated-${Date.now()}`;

    try {
      await bob.chat.openMessageContextMenu(parent);
      await bob.chat.contextReplyMenuItem.click();
      await expect(bob.chat.replyBar).toBeVisible();
      await expect(bob.chat.replyBar).toContainText(alice.nick);
      await expect(bob.chat.replyBar).toContainText(parent);

      await bob.chat.sendMessage(reply);
      await bob.chat.expectMessageVisible(reply);
      await alice.chat.expectMessageVisible(reply);

      const replyBlock = bob.chat.messageRowByText(reply).getByTestId('reply-block');
      await expect(replyBlock).toBeVisible();
      await expect(replyBlock).toContainText(parent);

      await bob.chat.chatInput.press('ArrowUp');
      await expect(bob.chat.chatInput).toHaveValue(reply);
      await bob.chat.chatInput.fill(updated);
      await bob.chat.chatInput.press('Enter');

      await bob.chat.expectMessageVisible(updated);
      await alice.chat.expectMessageVisible(updated);
      await expect(bob.chat.messageRowByText(updated).getByTestId('edited-tag')).toBeVisible();
      await expect(alice.chat.messageRowByText(updated).getByTestId('edited-tag')).toBeVisible();

      await bob.chat.openMessageContextMenu(updated);
      await bob.chat.contextDeleteMenuItem.click();
      await expect(bob.chat.deleteConfirmButton).toBeVisible();
      await bob.chat.deleteConfirmButton.click();

      await expect(bob.chat.messageList.getByTestId('deleted-message')).toBeVisible();
      await expect(alice.chat.messageList.getByTestId('deleted-message')).toBeVisible();
      await expect(bob.chat.messageList.getByText(updated)).toHaveCount(0);
      await expect(alice.chat.messageList.getByText(updated)).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
