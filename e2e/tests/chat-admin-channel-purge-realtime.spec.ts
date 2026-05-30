import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'admpurge'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'admpurge',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

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

test.describe('Admin channel purge realtime', () => {
  test('purging an open channel removes visible history for all open clients (X11)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const alice = await newSignedInUser(browser, 'x11alice');
    const bob = await newSignedInUser(browser, 'x11bob');
    const channel = uniqueChannel('x11purge');
    const aliceText = `x11-alice-${Date.now()}`;
    const bobText = `x11-bob-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.expectNickInList(bob.nick);

      await alice.chat.sendMessage(aliceText);
      await bob.chat.expectMessageVisible(aliceText);

      await bob.chat.sendMessage(bobText);
      await alice.chat.expectMessageVisible(bobText);

      await admin.chat.sendMessage(`/admin channel purge ${channel}`);
      await admin.chat.expectMessageVisible(`messages from ${channel}.`);

      await alice.chat.expectMessageHidden(aliceText);
      await alice.chat.expectMessageHidden(bobText);
      await bob.chat.expectMessageHidden(aliceText);
      await bob.chat.expectMessageHidden(bobText);
    } finally {
      await admin.chat.sendMessage(`/admin channel delete ${channel}`);
      await closeUsers([admin, alice, bob]);
    }
  });
});
