import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'url'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'url') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe('URL Catcher', () => {
  test('captures chat links, updates preview titles, and search filters rows (O15)', async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page);
    const channel = uniqueChannel();
    const marker = Date.now();
    const keepToken = `keep${marker}`;
    const hideToken = `hide${marker}`;
    const keepUrl = `http://localhost:4003/connect?${keepToken}=1`;
    const hideUrl = `http://localhost:4003/connect?${hideToken}=1`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage(`first url ${keepUrl}`);
    await chat.expectMessageVisible(keepUrl);
    await chat.sendMessage(`second url ${hideUrl}`);
    await chat.expectMessageVisible(hideUrl);

    await chat.openUrlCatcherFromMenu();

    const keepRow = chat.urlCatcherRowByUrl(keepUrl);
    const hideRow = chat.urlCatcherRowByUrl(hideUrl);

    await expect(keepRow).toBeVisible();
    await expect(keepRow).toContainText(nick);
    await expect(keepRow).toContainText(channel);
    await expect(hideRow).toBeVisible();

    await expect(
      keepRow.getByTestId('url-catcher-preview-title'),
    ).toContainText('Connect - RetroHexChat', { timeout: 10_000 });

    await chat.urlCatcherSearch.fill(keepToken);

    await expect(chat.urlCatcherRowByUrl(keepUrl)).toBeVisible();
    await expect(chat.urlCatcherRows.filter({ hasText: hideUrl })).toHaveCount(
      0,
    );
  });
});
