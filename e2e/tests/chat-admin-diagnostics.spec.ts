import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
};

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx };
}

test.describe('Admin diagnostics', () => {
  test('/admin debug, log, and turn diagnostics render without crashing (M11)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.sendMessage('/admin debug memory');
      await admin.chat.expectMessageVisible('*** BEAM Memory ***');
      await admin.chat.expectMessageVisible('Total:');

      await admin.chat.sendMessage('/admin debug connections');
      await admin.chat.expectMessageVisible('*** Debug:');

      await admin.chat.sendMessage('/admin debug processes');
      await admin.chat.expectMessageVisible('Channel Processes');

      await admin.chat.sendMessage('/admin server info');
      await admin.chat.expectMessageVisible('Users online:');

      await admin.chat.sendMessage('/admin log --last 1');
      await admin.chat.expectMessageVisible('*** Audit Log');
      await admin.chat.expectMessageVisible(ADMIN_NICK);

      await admin.chat.sendMessage('/admin turn stats');
      await admin.chat.expectMessageVisible('TURN');
    } finally {
      await admin.ctx.close();
    }
  });
});
