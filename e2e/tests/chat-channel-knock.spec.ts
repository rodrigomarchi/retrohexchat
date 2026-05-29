import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'knock'): string {
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

test.describe('Channel knock', () => {
  test('/knock notifies channel operators and repeated knocks are throttled (I15)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('knock');
    const owner = await newSignedInUser(browser, 'own');
    const guest = await newSignedInUser(browser, 'nok');
    const message = `please-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage('/mode +i');

      await guest.chat.sendMessage(`/knock ${channel} ${message}`);

      await guest.chat.expectMessageVisible(`Knock sent to ${channel}`);
      await owner.chat.expectMessageVisible(
        `* ${guest.nick} has knocked on ${channel} (${message})`,
      );

      await guest.chat.sendMessage(`/knock ${channel} again`);
      await guest.chat.expectMessageVisible(
        `Please wait before knocking on ${channel} again`,
      );
    } finally {
      await closeUsers([owner, guest]);
    }
  });

  test('/mode +K disables knock and /mode -K allows it again (I16)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('noknock');
    const owner = await newSignedInUser(browser, 'own');
    const guest = await newSignedInUser(browser, 'nok');
    const message = `after-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage('/mode +i');
      await owner.chat.sendMessage('/mode +K');

      await guest.chat.sendMessage(`/knock ${channel} blocked`);
      await guest.chat.expectMessageVisible(
        'Knocking is disabled for this channel',
      );

      await owner.chat.sendMessage('/mode -K');
      await guest.chat.sendMessage(`/knock ${channel} ${message}`);

      await guest.chat.expectMessageVisible(`Knock sent to ${channel}`);
      await owner.chat.expectMessageVisible(
        `* ${guest.nick} has knocked on ${channel} (${message})`,
      );
    } finally {
      await closeUsers([owner, guest]);
    }
  });
});
