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

test.describe('Command history', () => {
  test('enhanced history recalls non-sensitive commands and skips NickServ commands (G9)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const sensitiveCommand = `/ns identify secret-${Date.now()}`;

    await chat.sendMessage('/help');
    await chat.expectMessageVisible('Available commands:');

    await chat.sendMessage(sensitiveCommand);

    await chat.chatInput.click();
    await chat.chatInput.press('Control+ArrowUp');

    await expect(chat.chatInput).toHaveValue('/help');

    await chat.chatInput.press('Control+ArrowDown');
    await expect(chat.chatInput).toHaveValue('');
  });

  test('Escape closes autocomplete, syntax tooltip, then history search without submitting (G10)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.chatInput.click();
    await chat.chatInput.pressSequentially('/join ');

    await expect(chat.autocompleteDropdown).toBeVisible();
    await expect(chat.syntaxTooltip).toBeVisible();

    await chat.chatInput.press('Escape');
    await expect(chat.autocompleteDropdown).toHaveCount(0);
    await expect(chat.syntaxTooltip).toBeVisible();

    await chat.chatInput.press('Escape');
    await expect(chat.syntaxTooltip).toHaveCount(0);

    await chat.sendMessage('/help');
    await chat.expectMessageVisible('Available commands:');

    const draft = `draft-${Date.now()}`;
    await chat.chatInput.fill(draft);
    await chat.chatInput.press('Control+r');

    await expect(chat.historySearch).toBeVisible();
    await expect(chat.historySearchInput).toBeFocused();

    await chat.historySearchInput.fill('help');
    await expect(chat.chatInput).toHaveValue('/help');

    await chat.historySearchInput.press('Escape');

    await expect(chat.historySearch).toBeHidden();
    await expect(chat.chatInput).toHaveValue(draft);
    await chat.expectMessageHidden(`Unknown command: ${draft}`);
  });
});
