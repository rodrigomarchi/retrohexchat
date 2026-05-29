import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('keys'));
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

async function openMenuItem(trigger: Locator, item: Locator) {
  await trigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

test.describe('Shortcut cheatsheet', () => {
  test('opens from Help menu and shortcut, lists active bindings, and does not submit draft input (T10)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const draft = `cheatsheet draft ${Date.now()}`;

    await chat.chatInput.fill(draft);
    await openMenuItem(chat.helpMenuTrigger, chat.cheatsheetMenuItem);
    await expect(chat.cheatsheetDialog).toBeVisible();
    await expect(chat.cheatsheetDialog).toContainText('Next Window');
    await expect(chat.cheatsheetDialog).toContainText('Ctrl+Shift+]');
    await expect(chat.cheatsheetDialog).toContainText('Open Address Book');
    await expect(chat.cheatsheetDialog).toContainText('Ctrl+Shift+A');
    await expect(chat.chatInput).toHaveValue(draft);
    await chat.expectMessageHidden(draft);

    await chat.cheatsheetCloseButton.click();
    await expect(chat.cheatsheetDialog).toBeHidden();
    await expect(chat.chatInput).toHaveValue(draft);

    await pressCtrlShift(page, '/');
    await expect(chat.cheatsheetDialog).toBeVisible();
    await expect(chat.chatInput).toHaveValue(draft);
    await chat.expectMessageHidden(draft);

    await page.keyboard.press('Escape');
    await expect(chat.cheatsheetDialog).toBeHidden();
    await expect(chat.chatInput).toHaveValue(draft);
  });
});
