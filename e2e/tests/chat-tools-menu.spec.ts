import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('tools'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

async function openToolsItem(chat: ChatPage, item: Locator) {
  await chat.toolsMenuTrigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

test.describe('Tools menu', () => {
  test('opens every major tools dialog from the menu (T5)', async ({ page }) => {
    const chat = await signedInUser(page);

    await openToolsItem(chat, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.addressBookDialog).toBeHidden();

    await openToolsItem(chat, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();
    await chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.highlightDialog).toBeHidden();

    await openToolsItem(chat, chat.urlCatcherMenuItem);
    await expect(chat.urlCatcherDialog).toBeVisible();
    await chat.urlCatcherDialog
      .getByRole('button', { name: 'Close' })
      .last()
      .click();
    await expect(chat.urlCatcherDialog).toBeHidden();

    await openToolsItem(chat, chat.channelCentralMenuItem);
    await expect(chat.channelCentralDialog).toBeVisible();
    await chat.channelCentralDialog
      .getByRole('button', { name: 'Close' })
      .last()
      .click();
    await expect(chat.channelCentralDialog).toBeHidden();

    await openToolsItem(chat, chat.performMenuItem);
    await expect(chat.performDialog).toBeVisible();
    await chat.performDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.performDialog).toBeHidden();

    await openToolsItem(chat, chat.soundSettingsMenuItem);
    await expect(chat.soundSettingsDialog).toBeVisible();
    await chat.soundSettingsDialog
      .getByRole('button', { name: 'Cancel' })
      .click();
    await expect(chat.soundSettingsDialog).toBeHidden();

    await openToolsItem(chat, chat.floodProtectionMenuItem);
    await expect(chat.floodProtectionDialog).toBeVisible();
    await chat.floodProtectionDialog
      .getByRole('button', { name: 'Cancel' })
      .click();
    await expect(chat.floodProtectionDialog).toBeHidden();

    await openToolsItem(chat, chat.aliasEditorMenuItem);
    await expect(chat.aliasDialog).toBeVisible();
    await chat.aliasDialog.getByRole('button', { name: 'Close' }).last().click();
    await expect(chat.aliasDialog).toBeHidden();

    await openToolsItem(chat, chat.customMenusMenuItem);
    await expect(chat.customMenusDialog).toBeVisible();
    await chat.customMenusDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.customMenusDialog).toBeHidden();

    await openToolsItem(chat, chat.autorespondMenuItem);
    await expect(chat.autorespondDialog).toBeVisible();
    await chat.autorespondDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.autorespondDialog).toBeHidden();
  });
});
