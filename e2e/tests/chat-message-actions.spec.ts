import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'actions'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'act') {
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
  prefix = 'act',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'acta');
  const bob = await newSignedInUser(browser, 'actb');

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);

  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);

  await alice.chat.switchToTab(channel);
  await alice.chat.expectNickInList(bob.nick);

  return { alice, bob };
}

test.describe('Message actions', () => {
  test('reply via message context menu creates a reply bar, sends a reply block, and dismiss cancels (O8)', async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page);
    const marker = Date.now();
    const original = `reply-original-${marker}`;
    const cancelled = `reply-cancelled-${marker}`;
    const reply = `reply-sent-${marker}`;

    await chat.sendMessage(original);
    await chat.expectMessageVisible(original);

    await chat.openMessageContextMenu(original);
    await chat.contextReplyMenuItem.click();

    await expect(chat.chatContextMenu).toBeHidden();
    await expect(chat.replyBar).toBeVisible();
    await expect(chat.replyBar).toContainText(nick);
    await expect(chat.replyBar).toContainText(original);

    await chat.replyBarDismissButton.click();
    await expect(chat.replyBar).toBeHidden();

    await chat.sendMessage(cancelled);
    await chat.expectMessageVisible(cancelled);
    await expect(
      chat.messageRowByText(cancelled).getByTestId('reply-block'),
    ).toHaveCount(0);

    await chat.openMessageContextMenu(original);
    await chat.contextReplyMenuItem.click();
    await expect(chat.replyBar).toBeVisible();

    await chat.sendMessage(reply);
    await chat.expectMessageVisible(reply);
    await expect(chat.replyBar).toBeHidden();

    const replyBlock = chat.messageRowByText(reply).getByTestId('reply-block');
    await expect(replyBlock).toBeVisible();
    await expect(replyBlock).toContainText(nick);
    await expect(replyBlock).toContainText(original);
  });

  test('ArrowUp edits the last own message and submit shows the edited tag (O9)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'edit');
    const marker = Date.now();
    const original = `edit-original-${marker}`;
    const updated = `edit-updated-${marker}`;

    await chat.sendMessage(original);
    await chat.expectMessageVisible(original);

    await chat.chatInput.press('ArrowUp');
    await expect(chat.chatInput).toHaveValue(original);

    await chat.chatInput.fill(updated);
    await chat.chatInput.press('Enter');

    const updatedRow = chat.messageRowByText(updated);
    await expect(updatedRow).toBeVisible();
    await expect(updatedRow.getByTestId('edited-tag')).toBeVisible();
    await expect(chat.chatInput).toHaveValue('');
  });

  test('deleting an own message shows a deleted placeholder for both channel users (O10)', async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const text = `delete-me-${Date.now()}`;

    try {
      await alice.chat.sendMessage(text);
      await alice.chat.expectMessageVisible(text);
      await bob.chat.expectMessageVisible(text);

      await alice.chat.openMessageContextMenu(text);
      await alice.chat.contextDeleteMenuItem.click();

      await expect(alice.chat.chatContextMenu).toBeHidden();
      await expect(alice.chat.deleteConfirmButton).toBeVisible();

      await alice.chat.deleteConfirmButton.click();
      await expect(alice.chat.deleteConfirmButton).toBeHidden();

      await expect(
        alice.chat.messageList.getByTestId('deleted-message'),
      ).toBeVisible();
      await expect(
        bob.chat.messageList.getByTestId('deleted-message'),
      ).toBeVisible();
      await expect(alice.chat.messageList.getByText(text)).toHaveCount(0);
      await expect(bob.chat.messageList.getByText(text)).toHaveCount(0);
    } finally {
      await alice.ctx.close();
      await bob.ctx.close();
    }
  });

  test('failed channel send renders retry and retry succeeds after permissions change (O11)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('retry');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const text = `retry-after-voice-${Date.now()}`;

    try {
      await alice.chat.sendMessage('/mode +m');
      await alice.chat.expectMessageVisible(`${alice.nick} sets mode +m`);

      await bob.chat.sendMessage(text);
      await expect(bob.chat.messageRowByText(text)).toHaveAttribute(
        'data-msg-status',
        'failed',
      );
      await expect(
        bob.chat.messageRowByText(text).getByTestId('retry-message'),
      ).toBeVisible();
      await alice.chat.expectMessageHidden(text);

      await alice.chat.sendMessage(`/voice ${bob.nick}`);
      await bob.chat.expectNickRole(bob.nick, 'voiced');

      await bob.chat.messageRowByText(text).getByTestId('retry-message').click();

      await alice.chat.expectMessageVisible(text);
      await bob.chat.expectMessageVisible(text);
      await expect(
        bob.chat.messageList.getByTestId('retry-message'),
      ).toHaveCount(0);
      await expect(bob.chat.messageRows.filter({ hasText: text })).toHaveCount(1);
    } finally {
      await alice.ctx.close();
      await bob.ctx.close();
    }
  });
});
