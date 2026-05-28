import { expect, test } from '@playwright/test';
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

test.describe('Command syntax tooltip', () => {
  test('typing /mode shows syntax guidance and tracks the next argument (G5)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.chatInput.click();
    await chat.chatInput.pressSequentially('/mode ');

    await expect(chat.syntaxTooltip).toBeVisible();
    await expect(chat.syntaxTooltip).toContainText('/mode');
    await expect(chat.syntaxTooltip).toContainText('<+/-flags>');
    await expect(chat.syntaxTooltip).toContainText('Change channel settings');

    await chat.chatInput.pressSequentially('+o ');

    await expect(chat.syntaxTooltip).toBeVisible();
    await expect(chat.syntaxTooltip).toContainText('[nick]');
    await expect(chat.syntaxTooltip).toContainText('+o');
  });
});
