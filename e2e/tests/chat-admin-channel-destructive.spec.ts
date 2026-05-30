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

function uniqueChannel(prefix = 'admdelete'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'admdelete',
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

test.describe('Admin destructive channel actions', () => {
  test('admin delete removes open channel tabs and later sends use the fallback tab (X10)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const alice = await newSignedInUser(browser, 'x10alice');
    const bob = await newSignedInUser(browser, 'x10bob');
    const channel = uniqueChannel('x10del');
    const lobbyText = `after-delete-lobby-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.expectNickInList(bob.nick);

      await admin.chat.sendMessage(`/admin channel delete ${channel}`);
      await admin.chat.expectMessageVisible(
        `Channel ${channel} has been deleted.`,
      );

      await alice.chat.expectTabHidden(channel);
      await bob.chat.expectTabHidden(channel);
      await alice.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.sendMessage(lobbyText);
      await alice.chat.expectMessageVisible(lobbyText);
      await alice.chat.expectTabHidden(channel);
    } finally {
      await admin.chat.sendMessage(`/admin channel delete ${channel}`);
      await closeUsers([admin, alice, bob]);
    }
  });
});
