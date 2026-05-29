import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

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
});
