import { expect, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname('qhist'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

async function historySnapshot(page: Page) {
  return page.evaluate(() => ({
    history: localStorage.getItem('retro_hex_chat_history') || '',
    recent: localStorage.getItem('retro_hex_chat_recent_commands') || '',
  }));
}

test.describe('Sensitive command history and recent command ranking', () => {
  test('sensitive command names and args are omitted from command history (Q9)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const secret = `secret-${Date.now()}`;

    await chat.sendMessage('/help');
    await chat.expectMessageVisible('Available commands:');

    await chat.sendMessage(`/msg NickServ identify ${secret}`);
    await chat.sendMessage(`/perform add /ns identify ${secret}`);
    await chat.sendMessage(`/alias add qauth /ns identify ${secret}`);

    const snapshot = await historySnapshot(page);
    expect(snapshot.history).not.toContain(secret);
    expect(snapshot.history).not.toContain('NickServ identify');
    expect(snapshot.history).not.toContain('/perform add /ns identify');
    expect(snapshot.history).not.toContain('/alias add qauth');

    await chat.chatInput.click();
    await chat.chatInput.press('Control+ArrowUp');
    await expect(chat.chatInput).toHaveValue('/help');
  });

  test('recent command autocomplete ranks safe commands and does not leak sensitive commands (Q10)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const secret = `recent-secret-${Date.now()}`;

    await chat.sendMessage('/help');
    await chat.expectMessageVisible('Available commands:');

    await chat.sendMessage('/away ranking-check');
    await chat.expectMessageVisible('You are now away: ranking-check');

    await chat.sendMessage(`/ns identify ${secret}`);
    await chat.expectMessageVisible('[NickServ]');

    const snapshot = await historySnapshot(page);
    expect(snapshot.recent).toContain('away');
    expect(snapshot.recent).not.toContain('ns');
    expect(snapshot.recent).not.toContain(secret);

    await chat.chatInput.click();
    await chat.chatInput.pressSequentially('/a');
    await expect(chat.autocompleteDropdown).toBeVisible();
    await expect(chat.autocompleteDropdown).toContainText('Recent');

    const firstItem = chat.autocompleteDropdown
      .locator('[data-testid^="autocomplete-item-"]')
      .first();
    await expect(firstItem).toContainText('/away');
    await expect(chat.autocompleteDropdown).not.toContainText(secret);
  });
});
