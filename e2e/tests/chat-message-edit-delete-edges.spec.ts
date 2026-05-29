import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('editempty'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

test.describe('Message edit/delete edge cases', () => {
  test('editing a message to empty opens delete confirmation and cancel restores normal input state (R10)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const marker = Date.now();
    const original = `empty-edit-original-${marker}`;
    const afterCancel = `empty-edit-after-cancel-${marker}`;

    await chat.sendMessage(original);
    const originalRow = chat.messageRowByText(original);
    await expect(originalRow).toBeVisible();

    await chat.chatInput.press('ArrowUp');
    await expect(chat.chatInput).toHaveValue(original);

    await chat.chatInput.fill('');
    await chat.chatInput.press('Enter');

    await expect(chat.deleteConfirmButton).toBeVisible();
    await expect(chat.chatInput).toHaveValue('');
    await expect(chat.chatSendButton).toBeDisabled();

    await chat.deleteCancelButton.click();

    await expect(chat.deleteConfirmButton).toBeHidden();
    await expect(originalRow).toBeVisible();
    await expect(chat.messageList.getByTestId('deleted-message')).toHaveCount(0);
    await expect(chat.chatInput).toBeEnabled();
    await expect(chat.chatInput).toHaveValue('');
    await expect(chat.chatSendButton).toBeDisabled();

    await chat.sendMessage(afterCancel);
    await chat.expectMessageVisible(afterCancel);
  });
});
