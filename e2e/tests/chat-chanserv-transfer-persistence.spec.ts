import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'cstransfer'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'cstransfer') {
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
  prefix = 'cstransfer',
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

test.describe('ChanServ founder transfer persistence', () => {
  test('transferred founder controls future access after empty-channel rejoin (X7)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, 'TestAdmin', 'adminpass1');
    const founder = await newSignedInUser(browser, 'x7old');
    const newFounder = await newSignedInUser(browser, 'x7new');
    const channel = uniqueChannel('x7cs');

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);

      await founder.chat.sendMessage('/cs register');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} registered by ${founder.nick}`,
      );

      await admin.chat.sendMessage(
        `/admin cs transfer ${channel} ${newFounder.nick}`,
      );
      await admin.chat.expectMessageVisible(
        `*** Founder of ${channel} transferred to ${newFounder.nick}`,
      );

      await founder.chat.sendMessage('/cs info');
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${channel}: founder=${newFounder.nick}`,
      );

      await founder.chat.sendMessage('/cs drop');
      await founder.chat.expectMessageVisible(
        '[ChanServ] Only the founder can drop a channel',
      );

      await founder.chat.sendMessage(`/part ${channel}`);
      await founder.chat.expectTabHidden(channel);

      await newFounder.chat.sendMessage(`/join ${channel}`);
      await newFounder.chat.expectTabVisible(channel);
      await newFounder.chat.expectNickRole(newFounder.nick, 'owner');

      await newFounder.chat.sendMessage('/cs drop');
      await newFounder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} dropped`,
      );

      await newFounder.chat.sendMessage('/cs info');
      await newFounder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} is not registered`,
      );
    } finally {
      await closeUsers([admin, founder, newFounder]);
    }
  });
});
