import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('pastelimit'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

function pastedRows(chat: ChatPage, marker: string): Locator {
  return chat.messageRows.filter({ hasText: marker });
}

test.describe('Paste confirmation limits', () => {
  test('paste confirmation disables send above max line count and cancel restores input focus (R7)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const marker = `paste-limit-${Date.now()}`;
    const lines = Array.from(
      { length: 101 },
      (_, index) => `${marker}-${String(index + 1).padStart(3, '0')}`,
    );

    await chat.pasteText(lines.join('\n'));

    await expect(chat.pasteConfirmSendButton).toBeVisible();
    await expect(chat.pasteConfirmDialog).toContainText('101');
    await expect(chat.pasteConfirmDialog).toContainText('lines');
    await expect(chat.pasteFloodWarning).toBeVisible();
    await expect(chat.pasteConfirmSendButton).toBeDisabled();

    await chat.pasteConfirmCancelButton.click();

    await expect(chat.pasteConfirmSendButton).toBeHidden();
    await expect(chat.chatInput).toHaveValue('');
    await expect(chat.chatInput).toBeFocused();
    await expect(pastedRows(chat, marker)).toHaveCount(0);
  });
});
