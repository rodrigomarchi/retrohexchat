import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'cshier'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'cshier') {
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
  prefix = 'cshier',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('ChanServ access hierarchy', () => {
  test('SOP outranks AOP/VOP for permissions and automatic role assignment (X8)', async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, 'x8found');
    const sop = await newSignedInUser(browser, 'x8sop');
    const aop = await newSignedInUser(browser, 'x8aop');
    const vop = await newSignedInUser(browser, 'x8vop');
    const channel = uniqueChannel('x8cs');

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);

      await founder.chat.sendMessage('/cs register');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} registered by ${founder.nick}`,
      );

      await founder.chat.sendMessage(`/cs sop add ${sop.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${sop.nick} added to sop list of ${channel}`,
      );

      await founder.chat.sendMessage(`/cs aop add ${aop.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${aop.nick} added to aop list of ${channel}`,
      );

      await founder.chat.sendMessage(`/cs vop add ${vop.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${vop.nick} added to vop list of ${channel}`,
      );

      await sop.chat.sendMessage(`/join ${channel}`);
      await sop.chat.expectTabVisible(channel);
      await sop.chat.expectNickRole(sop.nick, 'owner');

      await aop.chat.sendMessage(`/join ${channel}`);
      await aop.chat.expectTabVisible(channel);
      await aop.chat.expectNickRole(aop.nick, 'operator');

      await vop.chat.sendMessage(`/join ${channel}`);
      await vop.chat.expectTabVisible(channel);
      await vop.chat.expectNickRole(vop.nick, 'voiced');

      await aop.chat.sendMessage(`/cs sop add ${vop.nick}`);
      await aop.chat.expectMessageVisible(
        '[ChanServ] Insufficient permission to manage sop access',
      );

      await sop.chat.sendMessage(`/cs aop del ${aop.nick}`);
      await sop.chat.expectMessageVisible(
        `[ChanServ] ${aop.nick} removed from access list of ${channel}`,
      );

      await aop.chat.sendMessage(`/part ${channel}`);
      await aop.chat.expectTabHidden(channel);

      await aop.chat.sendMessage(`/join ${channel}`);
      await aop.chat.expectTabVisible(channel);
      await aop.chat.expectNickRole(aop.nick, 'regular');
    } finally {
      await closeUsers([founder, sop, aop, vop]);
    }
  });
});
