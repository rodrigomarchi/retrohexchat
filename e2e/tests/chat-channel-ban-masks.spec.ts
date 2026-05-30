import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'banmask'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'banmask') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function signedInUserWithNick(page: Page, nick: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'banmask',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function newSignedInUserWithNick(
  browser: Browser,
  nick: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUserWithNick(page, nick);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Channel ban masks', () => {
  test('wildcard hostmask bans block matching nicks and spare non-matching nicks (X3)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'x3own');
    const matchingNick = uniqueNickname('x3mask');
    const free = await newSignedInUser(browser, 'x3free');
    const channel = uniqueChannel('x3ban');
    const banPrefix = matchingNick.slice(0, matchingNick.length - 2);
    const banMask = `${banPrefix}*!*@*`;
    const users = [owner, free];

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await owner.chat.sendMessage(`/mode +b ${banMask}`);
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +b`);

      const matching = await newSignedInUserWithNick(browser, matchingNick);
      users.push(matching);

      await matching.chat.sendMessage(`/join ${channel}`);
      await matching.chat.expectMessageVisible(`You are banned from ${channel}`);
      await matching.chat.expectTabHidden(channel);

      await free.chat.sendMessage(`/join ${channel}`);
      await free.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(free.nick);

      await owner.chat.sendMessage(`/mode -b ${banMask}`);
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode -b`);

      await matching.chat.sendMessage(`/join ${channel}`);
      await matching.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(matching.nick);
    } finally {
      await closeUsers(users);
    }
  });
});
