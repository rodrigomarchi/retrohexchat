import { test, expect, Locator } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: import('@playwright/test').Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname('paste'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

function pastedRows(chat: ChatPage, marker: string): Locator {
  return chat.messageRows.filter({ hasText: marker });
}

async function expectPastedLinesInOrder(
  chat: ChatPage,
  marker: string,
  lines: string[],
  timeout = 10_000,
) {
  const rows = pastedRows(chat, marker);
  await expect(rows).toHaveCount(lines.length, { timeout });
  const texts = await rows.allTextContents();

  for (const [index, line] of lines.entries()) {
    expect(texts[index]).toContain(line);
  }
}

test.describe('Multi-line paste', () => {
  test('shows confirmation dialog and supports cancel/send paths (O4)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const marker = `paste-${Date.now()}`;
    const cancelLines = [`cancel-${marker}-1`, `cancel-${marker}-2`];
    const sendLines = [`send-${marker}-1`, `send-${marker}-2`];

    await chat.pasteText(cancelLines.join('\n'));
    await expect(chat.pasteConfirmSendButton).toBeVisible();
    await expect(chat.pasteConfirmDialog).toContainText('2 lines');

    await chat.pasteConfirmCancelButton.click();
    await expect(chat.pasteConfirmSendButton).toBeHidden();
    await expect(chat.chatInput).toHaveValue('');
    await expect(pastedRows(chat, `cancel-${marker}`)).toHaveCount(0);

    await chat.pasteText(sendLines.join('\n'));
    await expect(chat.pasteConfirmSendButton).toBeVisible();
    await chat.pasteConfirmSendButton.click();
    await expect(chat.pasteConfirmSendButton).toBeHidden();

    await expectPastedLinesInOrder(chat, `send-${marker}`, sendLines);
  });

  test('shows flood warning for large paste and preserves sequential order (O5)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const marker = `flood-${Date.now()}`;
    const lines = Array.from(
      { length: 51 },
      (_, index) => `${marker}-${String(index + 1).padStart(2, '0')}`,
    );

    await chat.pasteText(lines.join('\n'));
    await expect(chat.pasteConfirmSendButton).toBeVisible();
    await expect(chat.pasteFloodWarning).toBeVisible();
    await expect(chat.pasteConfirmSendButton).toBeEnabled();

    await chat.pasteConfirmSendButton.click();
    await expectPastedLinesInOrder(chat, marker, lines, 25_000);
  });
});
