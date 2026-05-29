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

test.describe('User commands', () => {
  test('/query opens an empty PM tab without notifying the target (J1)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'qrya');
    const bob = await newSignedInUser(browser, 'qryb');

    try {
      await alice.chat.sendMessage(`/query ${bob.nick}`);

      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectActiveMessageCount(0);
      await bob.chat.expectTabHidden(alice.nick);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
