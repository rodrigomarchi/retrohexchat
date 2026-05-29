import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'srhist'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'srhist') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function sendPasteLines(chat: ChatPage, lines: string[]) {
  await chat.pasteText(lines.join('\n'));
  await expect(chat.pasteConfirmSendButton).toBeVisible();
  await chat.pasteConfirmSendButton.click();
  await expect(chat.pasteConfirmSendButton).toBeHidden();
}

function activeHighlightRow(chat: ChatPage) {
  return chat.searchActiveHighlight.locator(
    'xpath=ancestor::*[@data-message-id][1]',
  );
}

async function expectSearchCount(chat: ChatPage, current: number, total: number) {
  await expect(chat.searchBarCount).toHaveText(`${current}/${total}`);
}

test.describe('Search history pagination', () => {
  test('history mode finds a match only available after scroll pagination (S7)', async ({
    page,
  }) => {
    test.setTimeout(90_000);

    const { chat } = await signedInUser(page, 'srhis');
    const channel = uniqueChannel();
    const marker = Date.now();
    const oldMatch = `search-history-old-${marker}`;
    const fillerLines = Array.from(
      { length: 55 },
      (_, index) => `search-history-filler-${marker}-${String(index + 1).padStart(2, '0')}`,
    );

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage(oldMatch);
    await chat.expectMessageVisible(oldMatch);

    await sendPasteLines(chat, fillerLines);
    await chat.expectMessageVisible(fillerLines.at(-1)!, 35_000);

    await chat.switchToTab('#lobby');
    await chat.switchToTab(channel);

    await chat.openSearchFromViewMenu();
    await chat.searchBarInput.fill(oldMatch);
    await expectSearchCount(chat, 0, 0);
    await expect(chat.searchHighlights).toHaveCount(0);

    await chat.searchBarHistory.click();
    await expect(chat.searchBarHistory).toBeChecked();
    await expectSearchCount(chat, 1, 1);
    await expect(chat.searchHighlights).toHaveCount(0);

    await chat.scrollMessagesToTop();

    await chat.expectMessageVisible(oldMatch, 10_000);
    await expect(chat.searchHighlights).toHaveCount(1);
    await expectSearchCount(chat, 1, 1);
    await expect(activeHighlightRow(chat)).toContainText(oldMatch);
  });
});
