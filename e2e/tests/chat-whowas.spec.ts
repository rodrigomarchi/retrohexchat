import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'whowas'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

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

test.describe('Whowas command', () => {
  test('/whowas bob after bob disconnects shows last seen data (J14)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('ww');
    const alice = await newSignedInUser(browser, 'wwa');
    const bob = await newSignedInUser(browser, 'wwb');

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.expectNickInList(bob.nick);

      await bob.chat.disconnect();

      await alice.chat.sendMessage(`/whowas ${bob.nick}`);
      await alice.chat.expectMessageVisible(`----- Whowas: ${bob.nick} -----`);
      await alice.chat.expectMessageVisible('Last seen:');
      await alice.chat.expectMessageVisible('Channels:');
      await alice.chat.expectMessageVisible('#lobby');
      await alice.chat.expectMessageVisible(channel);
      await alice.chat.expectMessageVisible('Quit message: Leaving');
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
