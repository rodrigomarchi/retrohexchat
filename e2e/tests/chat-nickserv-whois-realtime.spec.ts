import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'nswhois'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'nswhois') {
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
  prefix = 'nswhois',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function whoisTextSince(chat: ChatPage, start: number): Promise<string> {
  await expect
    .poll(async () => chat.messageRows.count())
    .toBeGreaterThan(start);

  return chat.messageRows.evaluateAll(
    (rows, firstNewRow) =>
      rows
        .slice(firstNewRow)
        .map((row) => row.textContent || '')
        .join('\n'),
    start,
  );
}

test.describe('NickServ whois realtime state', () => {
  test('registering and dropping NickServ state updates another user whois without reconnect (W4)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'w4a');
    const bob = await newSignedInUser(browser, 'w4b');
    const channel = uniqueChannel('nswhois');
    const nick = uniqueNickname('w4nick');
    const password = `pw-${Date.now().toString(36)}`;

    try {
      await alice.chat.sendMessage(`/nick ${nick}`);
      await alice.chat.confirmNickChange();
      await alice.chat.waitUntilConnected();
      await alice.chat.expectNickInList(nick);

      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.expectNickInList(nick);

      let beforeWhois = await bob.chat.messageRows.count();
      await bob.chat.sendMessage(`/whois ${nick}`);
      let whoisText = await whoisTextSince(bob.chat, beforeWhois);
      expect(whoisText).toContain(`----- Whois: ${nick} -----`);
      expect(whoisText).toContain('Registered: No');

      await alice.chat.sendMessage(`/ns register ${password}`);
      await alice.chat.expectMessageVisible(
        `[NickServ] Nickname ${nick} registered successfully`,
      );

      beforeWhois = await bob.chat.messageRows.count();
      await bob.chat.sendMessage(`/whois ${nick}`);
      whoisText = await whoisTextSince(bob.chat, beforeWhois);
      expect(whoisText).toContain(`----- Whois: ${nick} -----`);
      expect(whoisText).toContain('Registered: Yes');

      await alice.chat.sendMessage(`/ns drop ${password}`);
      await alice.chat.expectMessageVisible(
        `[NickServ] Registration for ${nick} dropped`,
      );

      beforeWhois = await bob.chat.messageRows.count();
      await bob.chat.sendMessage(`/whois ${nick}`);
      whoisText = await whoisTextSince(bob.chat, beforeWhois);
      expect(whoisText).toContain(`----- Whois: ${nick} -----`);
      expect(whoisText).toContain('Registered: No');
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
