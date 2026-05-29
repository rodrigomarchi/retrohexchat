import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'cs'): string {
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

test.describe('ChanServ commands', () => {
  test('/cs register and /cs info show founder; only founder can drop (K6/K10)', async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, 'csf');
    const other = await newSignedInUser(browser, 'csn');
    const channel = uniqueChannel('reg');

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);

      await founder.chat.sendMessage('/cs register');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} registered by ${founder.nick}`,
      );

      await founder.chat.sendMessage('/cs info');
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${channel}: founder=${founder.nick}`,
      );

      await other.chat.sendMessage(`/join ${channel}`);
      await other.chat.expectTabVisible(channel);
      await other.chat.sendMessage('/cs drop');
      await other.chat.expectMessageVisible(
        '[ChanServ] Only the founder can drop a channel',
      );

      await founder.chat.sendMessage('/cs drop');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} dropped`,
      );

      await founder.chat.sendMessage('/cs info');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} is not registered`,
      );
    } finally {
      await closeUsers([founder, other]);
    }
  });

  test('/cs access lists grant auto-op/voice on join and del removes entries (K7-K9)', async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, 'cso');
    const aop = await newSignedInUser(browser, 'csa');
    const vop = await newSignedInUser(browser, 'csv');
    const channel = uniqueChannel('access');

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);

      await founder.chat.sendMessage('/cs register');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} registered by ${founder.nick}`,
      );

      await founder.chat.sendMessage(`/cs aop add ${aop.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${aop.nick} added to aop list of ${channel}`,
      );

      await founder.chat.sendMessage(`/cs vop add ${vop.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${vop.nick} added to vop list of ${channel}`,
      );

      await founder.chat.sendMessage('/cs aop list');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Access list for ${channel}`,
      );
      await founder.chat.expectMessageVisible(`${aop.nick} [aop]`);

      await founder.chat.sendMessage('/cs vop list');
      await founder.chat.expectMessageVisible(`${vop.nick} [vop]`);

      await founder.chat.sendMessage(`/part ${channel}`);
      await founder.chat.expectTabHidden(channel);

      await aop.chat.sendMessage(`/join ${channel}`);
      await aop.chat.expectTabVisible(channel);
      await aop.chat.expectNickRole(aop.nick, 'operator');

      await vop.chat.sendMessage(`/join ${channel}`);
      await vop.chat.expectTabVisible(channel);
      await vop.chat.expectNickRole(vop.nick, 'voiced');

      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);
      await founder.chat.expectNickRole(founder.nick, 'owner');

      await founder.chat.sendMessage(`/cs aop del ${aop.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${aop.nick} removed from access list of ${channel}`,
      );

      await founder.chat.sendMessage('/clear');
      await founder.chat.sendMessage('/cs aop list');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Access list for ${channel}`,
      );
      await founder.chat.expectMessageHidden(`${aop.nick} [aop]`);
    } finally {
      await closeUsers([founder, aop, vop]);
    }
  });
});
