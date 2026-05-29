import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('focus'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

async function expectMenuKeepsInputFocus(
  page: Page,
  trigger: Locator,
  visibleItem: Locator,
  chat: ChatPage,
) {
  await chat.chatInput.focus();
  await trigger.click();
  await expect(visibleItem).toBeVisible();
  await expect(chat.chatInput).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(visibleItem).toBeHidden();
  await expect(chat.chatInput).toBeFocused();
}

test.describe('Menu focus behavior', () => {
  test('menus keep chat input focus and intentional dialog inputs own focus (T2)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const draft = `focus draft ${Date.now()}`;

    await chat.chatInput.fill(draft);
    await expectMenuKeepsInputFocus(
      page,
      chat.fileMenuTrigger,
      chat.disconnectMenuItem,
      chat,
    );
    await expectMenuKeepsInputFocus(
      page,
      chat.viewMenuTrigger,
      chat.findMenuItem,
      chat,
    );
    await expectMenuKeepsInputFocus(
      page,
      chat.toolsMenuTrigger,
      chat.addressBookMenuItem,
      chat,
    );
    await expectMenuKeepsInputFocus(
      page,
      chat.helpMenuTrigger,
      chat.helpTopicsMenuItem,
      chat,
    );

    await chat.viewMenuTrigger.click();
    await chat.findMenuItem.click();
    await expect(chat.searchBarInput).toBeFocused();
    await expect(chat.chatInput).toHaveValue(draft);
    await chat.expectMessageHidden(draft);
  });
});
