import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'csperm'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'csperm') {
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
  prefix = 'csperm',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('ChanServ permission edges', () => {
  test('non-founder access mutations fail clearly without partial state changes (X9)', async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, 'x9found');
    const regular = await newSignedInUser(browser, 'x9reg');
    const target = await newSignedInUser(browser, 'x9target');
    const channel = uniqueChannel('x9cs');

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);

      await founder.chat.sendMessage('/cs register');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} registered by ${founder.nick}`,
      );

      await founder.chat.sendMessage(`/cs vop add ${target.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${target.nick} added to vop list of ${channel}`,
      );

      await regular.chat.sendMessage(`/join ${channel}`);
      await regular.chat.expectTabVisible(channel);
      await regular.chat.expectNickRole(regular.nick, 'regular');

      await regular.chat.sendMessage(`/cs aop add ${target.nick}`);
      await regular.chat.expectMessageVisible(
        '[ChanServ] Insufficient permission to manage aop access',
      );

      await regular.chat.sendMessage(`/cs vop del ${target.nick}`);
      await regular.chat.expectMessageVisible(
        '[ChanServ] Insufficient permission to manage vop access',
      );

      await founder.chat.sendMessage('/cs aop list');
      const aopList = founder.chat.messageRows
        .filter({ hasText: `[ChanServ] Access list for ${channel} (aop)` })
        .last();
      await expect(aopList).toContainText('(empty)');
      await expect(aopList).not.toContainText(`${target.nick} [aop]`);

      await founder.chat.sendMessage('/cs vop list');
      const vopList = founder.chat.messageRows
        .filter({ hasText: `[ChanServ] Access list for ${channel} (vop)` })
        .last();
      await expect(vopList).toContainText(`${target.nick} [vop]`);

      await target.chat.sendMessage(`/join ${channel}`);
      await target.chat.expectTabVisible(channel);
      await target.chat.expectNickRole(target.nick, 'voiced');
    } finally {
      await closeUsers([founder, regular, target]);
    }
  });
});
