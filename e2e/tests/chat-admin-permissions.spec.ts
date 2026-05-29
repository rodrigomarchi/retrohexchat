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
  prefix = 'perm',
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

test.describe('Admin command permission gates', () => {
  test('regular users cannot run server-only commands (M19)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'perm');

    try {
      await user.chat.sendMessage('/announce no access');
      await user.chat.expectMessageVisible(
        'Permission denied: you must be a server administrator.',
      );

      await user.chat.sendMessage('/setmotd no access');
      await user.chat.expectMessageVisible(
        'Permission denied: you must be a server administrator.',
      );

      await user.chat.sendMessage('/clearmotd');
      await user.chat.expectMessageVisible(
        'Permission denied: you must be a server administrator.',
      );

      await user.chat.sendMessage('/singleplayer');
      await user.chat.expectMessageVisible(
        'This command is reserved for administrators.',
      );
    } finally {
      await user.ctx.close();
    }
  });
});
