import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'kbd'): string {
  return `#z${prefix}${Date.now().toString(36)}${Math.random()
    .toString(36)
    .slice(2, 6)}`;
}

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('kbd'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

async function pressCtrlShift(page: Page, key: string) {
  await page.keyboard.down('Control');
  await page.keyboard.down('Shift');
  await page.keyboard.press(key);
  await page.keyboard.up('Shift');
  await page.keyboard.up('Control');
}

test.describe('Keyboard shortcuts', () => {
  test('open dialogs, switch windows, and do not submit input text (O18)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const channel = uniqueChannel();
    const draft = `keyboard draft ${Date.now()}`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabSelected(channel);

    await chat.chatInput.fill(draft);
    await pressCtrlShift(page, '/');
    await expect(chat.cheatsheetDialog).toBeVisible();
    await expect(chat.cheatsheetDialog).toContainText('Shortcut Cheatsheet');
    await expect(chat.chatInput).toHaveValue(draft);
    await chat.expectMessageHidden(draft);
    await page.keyboard.press('Escape');
    await expect(chat.cheatsheetDialog).toBeHidden();

    await pressCtrlShift(page, 'A');
    await expect(chat.addressBookDialog).toBeVisible();
    await expect(chat.chatInput).toHaveValue(draft);
    await chat.expectMessageHidden(draft);
    await page.keyboard.press('Escape');
    await expect(chat.addressBookDialog).toBeHidden();

    await chat.chatInput.fill('');
    await pressCtrlShift(page, '1');
    await chat.expectTabSelected('#lobby');
    await pressCtrlShift(page, '2');
    await chat.expectTabSelected(channel);
  });
});
