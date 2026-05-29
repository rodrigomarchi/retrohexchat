import { BrowserContext, Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'unicode'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname('unicode');

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function expectRowTextParts(row: Locator, parts: string[]) {
  for (const part of parts) {
    await expect.poll(() => row.evaluate((el) => el.textContent || '')).toContain(part);
  }
}

function activeHighlightRow(chat: ChatPage) {
  return chat.searchActiveHighlight.locator(
    'xpath=ancestor::*[@data-message-id][1]',
  );
}

async function expectClipboardContainsParts(
  context: BrowserContext,
  page: Page,
  parts: string[],
) {
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], {
    origin: 'http://localhost:4003',
  });

  for (const part of parts) {
    await expect
      .poll(() => page.evaluate(() => navigator.clipboard.readText()))
      .toContain(part);
  }
}

test.describe('Unicode message lifecycle', () => {
  test('unicode survives send, reload, edit, search, and visible copy flows (R5)', async ({
    context,
    page,
  }) => {
    const { chat, nick } = await signedInUser(page);
    const channel = uniqueChannel();
    const marker = `unicode-${Date.now()}`;
    const original = `${marker} café Cafe\u0301 Привет こんにちは مرحبا 😀🏳️‍🌈`;
    const updated = `${marker}-edited mañana nin\u0303o 漢字 Καλημέρα 🚀`;

    await context.grantPermissions(['clipboard-read', 'clipboard-write'], {
      origin: 'http://localhost:4003',
    });

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);
    await chat.expectTabSelected(channel);

    await chat.sendMessage(original);
    const originalRow = chat.messageRowByText(marker);
    await expect(originalRow).toBeVisible();
    await expectRowTextParts(originalRow, [
      marker,
      'café',
      'Cafe\u0301',
      'Привет',
      'こんにちは',
      'مرحبا',
      '😀',
      '🏳️‍🌈',
    ]);

    await page.waitForFunction(
      ([expectedNick, expectedChannel]) => {
        const raw = localStorage.getItem('rhc_reconnect_state');
        if (!raw) return false;

        const state = JSON.parse(raw);
        return (
          state.nickname === expectedNick &&
          state.active_channel === expectedChannel &&
          state.channels.includes(expectedChannel)
        );
      },
      [nick, channel],
    );

    await page.reload();
    await chat.waitUntilConnected();
    await chat.expectTabVisible(channel);
    await chat.expectTabSelected(channel);

    const reloadedRow = chat.messageRowByText(marker);
    await expect(reloadedRow).toBeVisible({ timeout: 10_000 });
    await expectRowTextParts(reloadedRow, ['Cafe\u0301', 'こんにちは', '🏳️‍🌈']);

    await chat.chatInput.press('ArrowUp');
    await expect(chat.chatInput).toHaveValue(original);

    await chat.chatInput.fill(updated);
    await chat.chatInput.press('Enter');

    const updatedRow = chat.messageRowByText(`${marker}-edited`);
    await expect(updatedRow).toBeVisible();
    await expect(updatedRow.getByTestId('edited-tag')).toBeVisible();
    await expectRowTextParts(updatedRow, [
      `${marker}-edited`,
      'mañana',
      'nin\u0303o',
      '漢字',
      'Καλημέρα',
      '🚀',
    ]);
    await expect(chat.messageRowByText(original)).toHaveCount(0);

    await chat.openSearchFromViewMenu();
    await chat.searchBarInput.fill('漢字');
    await expect(chat.searchHighlights).toHaveCount(1);
    await expect(activeHighlightRow(chat)).toContainText(`${marker}-edited`);

    await chat.openMessageContextMenu(`${marker}-edited`);
    await chat.contextCopyMessageMenuItem.click();
    await expect(chat.chatContextMenu).toBeHidden();
    await expectClipboardContainsParts(context, page, [
      `${marker}-edited`,
      'mañana',
      'nin\u0303o',
      '漢字',
      'Καλημέρα',
      '🚀',
    ]);
  });
});
