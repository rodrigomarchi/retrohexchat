import {
  Browser,
  BrowserContext,
  Locator,
  Page,
  test,
  expect,
} from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'hist'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'hist') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'hist',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

function markerRows(chat: ChatPage, marker: string): Locator {
  return chat.messageRows.filter({ hasText: marker });
}

function markerTokens(texts: string[], marker: string): Set<string | undefined> {
  return new Set(
    texts.map((text) => text.match(new RegExp(`${marker}-\\d{2}`))?.[0]),
  );
}

async function pasteLines(chat: ChatPage, lines: string[]) {
  await chat.pasteText(lines.join('\n'));
  await expect(chat.pasteConfirmSendButton).toBeVisible();
  await chat.pasteConfirmSendButton.click();
}

test.describe('Chat history pagination', () => {
  test('channel scroll loads older history without duplicate messages (P10)', async ({
    page,
  }) => {
    test.setTimeout(60_000);

    const { chat } = await signedInUser(page);
    const channel = uniqueChannel();
    const marker = `chan-history-${Date.now()}`;
    const lines = Array.from(
      { length: 60 },
      (_, index) => `${marker}-${String(index + 1).padStart(2, '0')}`,
    );

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await pasteLines(chat, lines);
    await expect(markerRows(chat, marker)).toHaveCount(lines.length, {
      timeout: 30_000,
    });

    await chat.switchToTab('#lobby');
    await chat.switchToTab(channel);

    await expect(markerRows(chat, marker)).toHaveCount(50);
    await chat.expectMessageHidden(lines[0]);
    await chat.expectMessageVisible(lines[59]);

    await chat.scrollMessagesToTop();

    await expect(markerRows(chat, marker)).toHaveCount(lines.length, {
      timeout: 10_000,
    });

    const texts = await markerRows(chat, marker).allTextContents();
    const seen = markerTokens(texts, marker);

    expect(seen.size).toBe(lines.length);
    expect(texts[0]).toContain(lines[0]);
    expect(texts[texts.length - 1]).toContain(lines[59]);
  });

  test('PM scroll loads older history without duplicate messages (P10)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newSignedInUser(browser, 'phia');
    const bob = await newSignedInUser(browser, 'phib');

    try {
      const marker = `pm-history-${Date.now()}`;
      const lines = Array.from(
        { length: 60 },
        (_, index) => `${marker}-${String(index + 1).padStart(2, '0')}`,
      );

      await alice.chat.sendMessage(`/query ${bob.nick}`);
      await alice.chat.expectTabSelected(bob.nick);

      await pasteLines(alice.chat, lines);
      await expect(markerRows(alice.chat, marker)).toHaveCount(lines.length, {
        timeout: 30_000,
      });

      await alice.chat.switchToTab('#lobby');
      await alice.chat.switchToTab(bob.nick);

      await expect(markerRows(alice.chat, marker)).toHaveCount(50);
      await alice.chat.expectMessageHidden(lines[0]);
      await alice.chat.expectMessageVisible(lines[59]);

      await alice.chat.scrollMessagesToTop();

      await expect(markerRows(alice.chat, marker)).toHaveCount(lines.length, {
        timeout: 10_000,
      });

      const texts = await markerRows(alice.chat, marker).allTextContents();
      const seen = markerTokens(texts, marker);

      expect(seen.size).toBe(lines.length);
      expect(texts[0]).toContain(lines[0]);
      expect(texts[texts.length - 1]).toContain(lines[59]);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
