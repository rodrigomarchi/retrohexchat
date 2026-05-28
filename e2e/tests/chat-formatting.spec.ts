import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: import('@playwright/test').Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname());
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

test.describe('Formatting toolbar', () => {
  test('Bold button inserts the IRC bold control code at the cursor (F2)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.chatInput.fill('hello');
    await chat.chatInput.press('End');
    await chat.formatBoldButton.click();

    await expect(chat.chatInput).toHaveValue('hello\x02');
    await expect(chat.chatInput).toBeFocused();
  });
});
