import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('dlg'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

async function openToolsItem(chat: ChatPage, item: Locator) {
  await chat.toolsMenuTrigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

async function expectFocusInside(page: Page, selector: string) {
  await expect
    .poll(() =>
      page.evaluate((dialogSelector) => {
        const dialog = document.querySelector(dialogSelector);
        return !!dialog && dialog.contains(document.activeElement);
      }, selector),
    )
    .toBe(true);
}

test.describe('Dialog keyboard behavior', () => {
  test('Escape closes only the topmost dialog layer and preserves underlying state (T6)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const contactAddForm = page.getByTestId('contact-add-form');

    await openToolsItem(chat, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog.getByRole('button', { name: 'Add' }).click();
    await expect(contactAddForm).toBeVisible();

    await page.keyboard.press('Escape');
    await expect(contactAddForm).toBeHidden();
    await expect(chat.addressBookDialog).toBeVisible();

    await page.keyboard.press('Escape');
    await expect(chat.addressBookDialog).toBeHidden();

    await chat.chatInput.focus();
    await chat.helpMenuTrigger.click();
    await expect(chat.helpTopicsMenuItem).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(chat.helpTopicsMenuItem).toBeHidden();
    await expect(chat.chatInput).toBeFocused();
  });

  test('Enter submits primary sub-dialog action and Escape discards drafts (T7)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const savedWord = `keep${Date.now().toString(36)}`;
    const cancelledWord = `drop${Date.now().toString(36)}`;
    const highlightAddForm = page.getByTestId('highlight-add-form');

    await openToolsItem(chat, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();

    await chat.highlightDialog.getByRole('button', { name: 'Add' }).click();
    await expect(highlightAddForm).toBeVisible();
    await page.locator('#highlight-word-input').fill(savedWord);
    await page.locator('#highlight-word-input').press('Enter');
    await expect(highlightAddForm).toBeHidden();
    await expect(chat.highlightDialog.getByText(savedWord)).toBeVisible();

    await chat.highlightDialog.getByRole('button', { name: 'Add' }).click();
    await expect(highlightAddForm).toBeVisible();
    await page.locator('#highlight-word-input').fill(cancelledWord);
    await page.keyboard.press('Escape');
    await expect(highlightAddForm).toBeHidden();
    await expect(chat.highlightDialog.getByText(cancelledWord)).toHaveCount(0);

    await chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.highlightDialog).toBeHidden();
  });

  test('Tab focus stays inside major dialogs (T8)', async ({ page }) => {
    const chat = await signedInUser(page);

    await openToolsItem(chat, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await expectFocusInside(page, '#address-book-dialog [role="dialog"]');

    for (let i = 0; i < 8; i++) {
      await page.keyboard.press('Tab');
      await expectFocusInside(page, '#address-book-dialog [role="dialog"]');
    }

    await page.keyboard.down('Shift');
    await page.keyboard.press('Tab');
    await page.keyboard.up('Shift');
    await expectFocusInside(page, '#address-book-dialog [role="dialog"]');

    await page.keyboard.press('Escape');
    await expect(chat.addressBookDialog).toBeHidden();
  });
});
