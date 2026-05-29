import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'time') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  timezoneId: string,
): Promise<TestUser> {
  const ctx = await browser.newContext({ timezoneId });
  const page = await ctx.newPage();
  const user = await signedInUser(page, 'time');

  return { chat: user.chat, ctx, nick: user.nick };
}

function timestampCandidates(timezoneId: string, startMs: number, endMs: number) {
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: timezoneId,
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  });

  const candidates = new Set<string>();

  for (let ms = startMs - 60_000; ms <= endMs + 60_000; ms += 30_000) {
    const parts = Object.fromEntries(
      formatter.formatToParts(new Date(ms)).map((part) => [part.type, part.value]),
    );
    candidates.add(`[${parts.day}/${parts.month} ${parts.hour}:${parts.minute}]`);
  }

  return candidates;
}

test.describe('Message timestamps', () => {
  test('timestamps use detected browser timezone and the default dd/mm HH:MM format (S12)', async ({
    browser,
  }) => {
    const timezoneId = 'Pacific/Honolulu';
    const utcTimezone = 'Etc/UTC';
    const user = await newSignedInUser(browser, timezoneId);
    const text = `timezone-message-${Date.now()}`;

    try {
      const startMs = Date.now();
      await user.chat.sendMessage(text);
      await user.chat.expectMessageVisible(text);
      const endMs = Date.now();

      const timestamp = user.chat.messageTimestampByText(text);
      await expect(timestamp).toHaveText(/\[\d{2}\/\d{2} \d{2}:\d{2}\]/);

      const actual = (await timestamp.textContent())?.trim();
      expect(timestampCandidates(timezoneId, startMs, endMs)).toContain(actual);
      expect(timestampCandidates(utcTimezone, startMs, endMs)).not.toContain(actual);
    } finally {
      await user.ctx.close();
    }
  });
});
