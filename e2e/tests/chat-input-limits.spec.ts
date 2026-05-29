import { BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const MAX_MESSAGE_LENGTH = 1000;

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('limit'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

function overLimitText(marker: string) {
  return `${marker} ${'x'.repeat(MAX_MESSAGE_LENGTH)} overflow-sentinel`;
}

async function expectInputAtLimit(chat: ChatPage) {
  await expect(chat.chatInput).toHaveJSProperty('maxLength', MAX_MESSAGE_LENGTH);
  await expect
    .poll(() => chat.chatInput.inputValue().then((value) => value.length))
    .toBe(MAX_MESSAGE_LENGTH);
  await expect(chat.chatInput).not.toHaveValue(/overflow-sentinel/);
  await expect(chat.charCounter).toContainText('1000/1000');
  await expect(chat.chatSendButton).toBeEnabled();
}

async function pasteFromClipboard(
  context: BrowserContext,
  page: Page,
  chat: ChatPage,
  text: string,
) {
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], {
    origin: 'http://localhost:4003',
  });
  await page.evaluate((value) => navigator.clipboard.writeText(value), text);
  await chat.chatInput.click();
  await page.keyboard.press('ControlOrMeta+V');
}

test.describe('Chat input length limits', () => {
  test('1000-character limit is enforced for input, paste, Send button, and Enter (R6)', async ({
    context,
    page,
  }) => {
    const chat = await signedInUser(page);
    const typedMarker = `limit-typed-${Date.now()}`;
    const pasteMarker = `limit-paste-${Date.now()}`;

    await chat.chatInput.click();
    await page.keyboard.insertText(overLimitText(typedMarker));
    await expectInputAtLimit(chat);

    await chat.chatInput.press('Enter');
    const typedRow = chat.messageRowByText(typedMarker);
    await expect(typedRow).toBeVisible();
    await expect(typedRow).not.toContainText('overflow-sentinel');
    await expect(chat.chatInput).toHaveValue('');
    await expect(chat.chatSendButton).toBeDisabled();

    await pasteFromClipboard(context, page, chat, overLimitText(pasteMarker));
    await expectInputAtLimit(chat);

    await chat.chatSendButton.click();
    const pastedRow = chat.messageRowByText(pasteMarker);
    await expect(pastedRow).toBeVisible();
    await expect(pastedRow).not.toContainText('overflow-sentinel');
    await expect(chat.chatInput).toHaveValue('');
    await expect(chat.chatSendButton).toBeDisabled();
  });
});
