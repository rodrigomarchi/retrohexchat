import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'admsvc'): string {
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

test.describe('Admin service commands', () => {
  test('/admin ns info/resetpass/drop manages NickServ registrations (K11)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, 'TestAdmin', 'adminpass1');
    const target = await newSignedInUser(browser, 'ans');
    const resetPassword = `reset-${Date.now().toString(36)}`;
    const reloginUsers: TestUser[] = [];

    try {
      await target.chat.disconnect();

      await admin.chat.sendMessage(`/admin ns info ${target.nick}`);
      await admin.chat.expectMessageVisible(`*** [NickServ] ${target.nick}`);
      await admin.chat.expectMessageVisible('Registered:');

      await admin.chat.sendMessage(
        `/admin ns resetpass ${target.nick} ${resetPassword}`,
      );
      await admin.chat.expectMessageVisible(
        `*** Password for ${target.nick} has been reset`,
      );

      const relogin = await knownSignedInUser(
        browser,
        target.nick,
        resetPassword,
      );
      reloginUsers.push(relogin);
      await relogin.chat.expectNickInList(target.nick);
      await relogin.chat.disconnect();

      await admin.chat.sendMessage(`/admin ns drop ${target.nick}`);
      await admin.chat.expectMessageVisible(
        `*** Registration for ${target.nick} dropped by admin`,
      );

      await admin.chat.sendMessage(`/admin ns info ${target.nick}`);
      await admin.chat.expectMessageVisible(
        `[NickServ] Nickname ${target.nick} is not registered`,
      );
    } finally {
      await closeUsers([admin, target, ...reloginUsers]);
    }
  });

  test('/admin cs info/access/transfer/drop manages ChanServ registrations (K12)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, 'TestAdmin', 'adminpass1');
    const founder = await newSignedInUser(browser, 'acs');
    const newFounder = await newSignedInUser(browser, 'acf');
    const accessUser = await newSignedInUser(browser, 'aca');
    const channel = uniqueChannel('admcs');

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);
      await founder.chat.sendMessage('/cs register');
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} registered by ${founder.nick}`,
      );
      await founder.chat.sendMessage(`/cs aop add ${accessUser.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${accessUser.nick} added to aop list of ${channel}`,
      );

      await admin.chat.sendMessage(`/admin cs info ${channel}`);
      await admin.chat.expectMessageVisible(`*** [ChanServ] ${channel}`);
      await admin.chat.expectMessageVisible(`Founder: ${founder.nick}`);
      await admin.chat.expectMessageVisible(`${accessUser.nick} [aop]`);

      await admin.chat.sendMessage(`/admin cs access ${channel}`);
      await admin.chat.expectMessageVisible(`*** Access List for ${channel} ***`);
      await admin.chat.expectMessageVisible(`${accessUser.nick} [aop]`);

      await admin.chat.sendMessage(
        `/admin cs access ${channel} add vop ${newFounder.nick}`,
      );
      await admin.chat.expectMessageVisible(
        `*** ${newFounder.nick} added to vop list of ${channel}`,
      );

      await admin.chat.sendMessage(
        `/admin cs transfer ${channel} ${newFounder.nick}`,
      );
      await admin.chat.expectMessageVisible(
        `*** Founder of ${channel} transferred to ${newFounder.nick}`,
      );

      await admin.chat.sendMessage(`/admin cs info ${channel}`);
      await admin.chat.expectMessageVisible(`Founder: ${newFounder.nick}`);

      await admin.chat.sendMessage(
        `/admin cs access ${channel} del aop ${accessUser.nick}`,
      );
      await admin.chat.expectMessageVisible(
        `*** ${accessUser.nick} removed from access list of ${channel}`,
      );

      await admin.chat.sendMessage(`/admin cs access ${channel}`);
      const latestAccessList = admin.chat.messageRows
        .filter({ hasText: `*** Access List for ${channel} ***` })
        .last();
      await expect(latestAccessList).toBeVisible();
      await expect(latestAccessList).not.toContainText(
        `${accessUser.nick} [aop]`,
      );

      await admin.chat.sendMessage(`/admin cs drop ${channel}`);
      await admin.chat.expectMessageVisible(
        `*** Channel ${channel} dropped by admin`,
      );

      await admin.chat.sendMessage(`/admin cs info ${channel}`);
      await admin.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} is not registered`,
      );
    } finally {
      await closeUsers([admin, founder, newFounder, accessUser]);
    }
  });
});
