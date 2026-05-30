import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'p2pav',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

test.describe('P2P target availability', () => {
  test('P2P, call, file, and game commands reject registered users who are offline (Z1)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z1a');
    const bob = await newSignedInUser(browser, 'z1b');

    try {
      await bob.chat.disconnect();

      for (const command of ['p2p', 'call', 'sendfile', 'game']) {
        await alice.chat.sendMessage(`/${command} ${bob.nick}`);
        await alice.chat.expectMessageVisible(`User '${bob.nick}' is offline.`);
        await alice.chat.expectTabHidden(bob.nick);
      }
    } finally {
      await alice.ctx.close();
      await bob.ctx.close();
    }
  });
});
