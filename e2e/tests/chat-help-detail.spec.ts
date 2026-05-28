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

test.describe('Help details', () => {
  test('/help join renders command-specific inline help (G3)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.sendMessage('/help join');

    await expect(chat.inlineHelp).toBeVisible();
    await expect(chat.inlineHelp).toContainText('/join');
    await expect(chat.inlineHelp).toContainText('Enter a chat channel');
    await expect(chat.inlineHelp).toContainText('Open in Help Topics');
    await expect(chat.inlineHelp).not.toContainText('F1');
  });

  test('Help Topics menu opens the full help system without submitting draft input (G4)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const draft = `draft-${Date.now()}`;

    await chat.chatInput.fill(draft);
    await chat.helpMenuTrigger.click();
    await expect(chat.chatInput).toHaveValue(draft);
    await expect(chat.helpTopicsMenuItem).toBeVisible();

    await chat.helpTopicsMenuItem.click();

    await expect(page).toHaveURL(/\/chat\/help(\?.*)?$/);
    await expect(chat.helpContentPane).toBeVisible();
    await expect(chat.helpContentPane).toContainText('Welcome to RetroHexChat');
  });
});
