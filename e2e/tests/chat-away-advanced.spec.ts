import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'e2e') {
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
  prefix = 'e2e',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Away advanced behavior', () => {
  test('/away appears in /whois and sends a PM auto-reply once (J13)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'awya');
    const bob = await newSignedInUser(browser, 'awyb');
    const away = `away-auto-${Date.now()}`;
    const ping = `away-ping-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/away ${away}`);
      await bob.chat.expectMessageVisible(`You are now away: ${away}`);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await alice.chat.expectMessageVisible(`Away: ${away}`);

      await alice.chat.sendMessage(`/msg ${bob.nick} ${ping}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageVisible(`${bob.nick} is away: ${away}`);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
