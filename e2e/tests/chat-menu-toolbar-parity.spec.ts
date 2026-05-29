import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('menu'));
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

test.describe('Menu action parity', () => {
  test('menu items open the same shell surfaces as keyboard equivalents where both exist (T1)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await openMenuItem(chat.viewMenuTrigger, chat.findMenuItem);
    await expect(chat.searchBar).toBeVisible();
    await chat.searchBar.getByRole('button', { name: 'Close' }).click();
    await expect(chat.searchBar).toBeHidden();

    await pressCtrlShift(page, 'F');
    await expect(chat.searchBar).toBeVisible();
    await chat.searchBar.getByRole('button', { name: 'Close' }).click();
    await expect(chat.searchBar).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.addressBookDialog).toBeHidden();

    await pressCtrlShift(page, 'A');
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.addressBookDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();
    await chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.highlightDialog).toBeHidden();

    await pressCtrlShift(page, 'H');
    await expect(chat.highlightDialog).toBeVisible();
    await chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.highlightDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.urlCatcherMenuItem);
    await expect(chat.urlCatcherDialog).toBeVisible();
    await chat.urlCatcherDialog
      .getByRole('button', { name: 'Close' })
      .last()
      .click();
    await expect(chat.urlCatcherDialog).toBeHidden();

    await pressCtrlShift(page, 'S');
    await expect(chat.urlCatcherDialog).toBeVisible();
    await chat.urlCatcherDialog
      .getByRole('button', { name: 'Close' })
      .last()
      .click();
    await expect(chat.urlCatcherDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.performMenuItem);
    await expect(chat.performDialog).toBeVisible();
    await chat.performDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.performDialog).toBeHidden();

    await pressCtrlShift(page, 'E');
    await expect(chat.performDialog).toBeVisible();
    await chat.performDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.performDialog).toBeHidden();

    await openMenuItem(chat.helpMenuTrigger, chat.cheatsheetMenuItem);
    await expect(chat.cheatsheetDialog).toBeVisible();
    await chat.cheatsheetCloseButton.click();
    await expect(chat.cheatsheetDialog).toBeHidden();

    await pressCtrlShift(page, '/');
    await expect(chat.cheatsheetDialog).toBeVisible();
  });
});
