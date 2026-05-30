import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'cspersist'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'cspersist') {
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
  prefix = 'cspersist',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('ChanServ persistence', () => {
  test('registered channel access survives empty channel and later rejoin (X6)', async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, 'x6found');
    const aop = await newSignedInUser(browser, 'x6aop');
    const channel = uniqueChannel('x6cs');

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

      await founder.chat.sendMessage(`/part ${channel}`);
      await founder.chat.expectTabHidden(channel);

      await aop.chat.sendMessage(`/join ${channel}`);
      await aop.chat.expectTabVisible(channel);
      await aop.chat.expectNickRole(aop.nick, 'operator');

      await aop.chat.sendMessage(`/part ${channel}`);
      await aop.chat.expectTabHidden(channel);

      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);
      await founder.chat.expectNickRole(founder.nick, 'owner');

      await founder.chat.sendMessage('/cs info');
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${channel}: founder=${founder.nick}`,
      );
    } finally {
      await closeUsers([founder, aop]);
    }
  });
});
