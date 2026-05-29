import { Page, Locator, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'srnav'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'srnav') {
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

async function expectLocatorInsideMessageViewport(chat: ChatPage, locator: Locator) {
  await expect
    .poll(() =>
      locator.evaluate((el) => {
        const list = el.closest('[data-testid="chat-message-list"]');
        if (!list) return false;

        const locatorBox = el.getBoundingClientRect();
        const listBox = list.getBoundingClientRect();

        return locatorBox.top >= listBox.top && locatorBox.bottom <= listBox.bottom;
      }),
    )
    .toBe(true);
}

test.describe('Search result navigation', () => {
  test('active result scrolls into view and remains highlighted on next/previous (S8)', async ({
    page,
  }) => {
    test.setTimeout(90_000);

    const { chat } = await signedInUser(page, 'srnav');
    const channel = uniqueChannel();
    const marker = Date.now();
    const needle = `search-nav-${marker}`;
    const first = `${needle}-first`;
    const second = `${needle}-second`;
    const fillerLines = Array.from(
      { length: 35 },
      (_, index) => `search-nav-filler-${marker}-${String(index + 1).padStart(2, '0')}`,
    );

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage(first);
    await chat.expectMessageVisible(first);

    await sendPasteLines(chat, fillerLines);
    await chat.expectMessageVisible(fillerLines.at(-1)!, 30_000);

    await chat.sendMessage(second);
    await chat.expectMessageVisible(second);

    await chat.openSearchFromViewMenu();
    await chat.searchBarInput.fill(needle);

    await expect(chat.searchHighlights).toHaveCount(2);
    await expectSearchCount(chat, 1, 2);
    await expect(activeHighlightRow(chat)).toContainText(first);
    await expectLocatorInsideMessageViewport(chat, chat.searchActiveHighlight);

    await chat.searchBarNextButton.click();
    await expectSearchCount(chat, 2, 2);
    await expect(activeHighlightRow(chat)).toContainText(second);
    await expectLocatorInsideMessageViewport(chat, chat.searchActiveHighlight);

    await chat.searchBarPrevButton.click();
    await expectSearchCount(chat, 1, 2);
    await expect(activeHighlightRow(chat)).toContainText(first);
    await expectLocatorInsideMessageViewport(chat, chat.searchActiveHighlight);
  });
});
