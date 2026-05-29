import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('about'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

async function openMenuItem(trigger: Locator, item: Locator) {
  await trigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

test.describe('About dialog', () => {
  test('opens from Help menu and app logo, closes cleanly, and restores chat focus (T3)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.chatInput.focus();
    await openMenuItem(chat.helpMenuTrigger, chat.aboutMenuItem);
    await expect(chat.aboutDialog).toBeVisible();
    await expect(chat.aboutDialog).toContainText('About RetroHexChat');
    await chat.aboutOkButton.click();
    await expect(chat.aboutDialog).toBeHidden();
    await expect(chat.chatInput).toBeFocused();

    await chat.appLogo.click();
    await expect(chat.aboutDialog).toBeVisible();
    await expect(chat.aboutDialog).toContainText('Public Chat Platform');
    await chat.aboutOkButton.click();
    await expect(chat.aboutDialog).toBeHidden();
    await expect(chat.chatInput).toBeFocused();
  });
});
