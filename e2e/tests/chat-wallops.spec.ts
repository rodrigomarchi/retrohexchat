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

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Wallops and user modes', () => {
  test('/umode +w opts in and /umode -w opts out of wallops delivery (J17/J18)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, 'TestAdmin', 'adminpass1');
    const optedIn = await newSignedInUser(browser, 'wopa');
    const optedOut = await newSignedInUser(browser, 'wopb');
    const firstWallops = `wallops-one-${Date.now()}`;
    const secondWallops = `wallops-two-${Date.now()}`;

    try {
      await admin.chat.switchToStatusTab();
      await optedIn.chat.switchToStatusTab();
      await optedOut.chat.switchToStatusTab();

      await optedOut.chat.sendMessage('/wallops regular users cannot send');
      await optedOut.chat.expectStatusMessageVisible(
        'Permission denied: you must be a server operator.',
      );

      await optedIn.chat.sendMessage('/umode +w');
      await optedIn.chat.expectStatusMessageVisible('User mode +w enabled.');

      await admin.chat.sendMessage(`/wallops ${firstWallops}`);
      await admin.chat.expectStatusMessageVisible('Wallops sent.');
      await optedIn.chat.expectStatusMessageVisible(
        `[Wallops] ${admin.nick}: ${firstWallops}`,
      );
      await optedOut.chat.expectStatusMessageHidden(firstWallops);

      await optedIn.chat.sendMessage('/umode -w');
      await optedIn.chat.expectStatusMessageVisible('User mode -w disabled.');

      await admin.chat.sendMessage(`/wallops ${secondWallops}`);
      await admin.chat.expectStatusMessageVisible('Wallops sent.');
      await optedIn.chat.expectStatusMessageHidden(secondWallops);
      await optedOut.chat.expectStatusMessageHidden(secondWallops);
    } finally {
      await closeUsers([admin, optedIn, optedOut]);
    }
  });
});
