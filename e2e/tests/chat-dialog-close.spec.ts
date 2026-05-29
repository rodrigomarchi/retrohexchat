import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('close'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

async function openMenuItem(trigger: Locator, item: Locator) {
  await trigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

async function clickTitleClose(dialog: Locator) {
  await dialog.getByRole('button', { name: 'Close' }).first().click();
}

async function clickBackdrop(page: Page) {
  await page.mouse.click(20, 20);
}

test.describe('Dialog close behavior', () => {
  test('close buttons, cancel buttons, and backdrop paths close major dialogs consistently (T11)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await openMenuItem(chat.toolsMenuTrigger, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await clickTitleClose(chat.addressBookDialog);
    await expect(chat.addressBookDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await clickBackdrop(page);
    await expect(chat.addressBookDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(chat.addressBookDialog).toBeHidden();

    await openMenuItem(chat.viewMenuTrigger, chat.channelListMenuItem);
    await expect(chat.channelListDialog).toBeVisible();
    await clickTitleClose(chat.channelListDialog);
    await expect(chat.channelListDialog).toBeHidden();

    await openMenuItem(chat.viewMenuTrigger, chat.channelListMenuItem);
    await expect(chat.channelListDialog).toBeVisible();
    await chat.channelListDialog
      .getByRole('button', { name: 'Close' })
      .last()
      .click();
    await expect(chat.channelListDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();
    await clickBackdrop(page);
    await expect(chat.highlightDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();
    await chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.highlightDialog).toBeHidden();
  });
});
