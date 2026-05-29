import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

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

async function registeredNick(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('NickServ commands', () => {
  test('/nick then /ns register, identify, info, and drop cover nickname lifecycle (K1-K3)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'nsbase');
    const registeredNick = uniqueNickname('nsreg');
    const password = `pw-${Date.now().toString(36)}`;

    try {
      await alice.chat.sendMessage(`/nick ${registeredNick}`);
      await alice.chat.confirmNickChange();
      await alice.chat.expectNickInList(registeredNick);
      await alice.chat.expectNickNotInList(alice.nick);

      await alice.chat.sendMessage(`/ns register ${password}`);
      await alice.chat.expectMessageVisible(
        `[NickServ] Nickname ${registeredNick} registered successfully`,
      );

      await alice.chat.sendMessage('/ns info');
      await alice.chat.expectMessageVisible(`[NickServ] ${registeredNick}:`);
      await alice.chat.expectMessageVisible('identified: true');

      await alice.chat.sendMessage('/ns identify wrong-password');
      await alice.chat.expectMessageVisible('[NickServ] Invalid password');

      await alice.chat.sendMessage(`/ns identify ${password}`);
      await alice.chat.expectMessageVisible(
        `[NickServ] You are now identified as ${registeredNick}`,
      );

      await alice.chat.sendMessage('/ns drop wrong-password');
      await alice.chat.expectMessageVisible('[NickServ] Invalid password');

      await alice.chat.sendMessage(`/ns drop ${password}`);
      await alice.chat.expectMessageVisible(
        `[NickServ] Registration for ${registeredNick} dropped`,
      );

      await alice.chat.sendMessage('/ns info');
      await alice.chat.expectMessageVisible(
        `[NickServ] Nickname ${registeredNick} is not registered`,
      );
    } finally {
      await closeUsers([alice]);
    }
  });

  test('/nick to a registered nickname requires the NickServ password (K5)', async ({
    browser,
  }) => {
    const targetNick = uniqueNickname('nstgt');
    const targetPassword = `pw-${Date.now().toString(36)}`;
    const owner = await registeredNick(browser, targetNick, targetPassword);
    const alice = await newSignedInUser(browser, 'nschg');

    try {
      await owner.chat.disconnect();
      await owner.ctx.close();

      await alice.chat.sendMessage(`/nick ${targetNick}`);
      await expect(alice.chat.nickChangeDialog).toBeVisible();
      await expect(alice.chat.nickChangeDialog).toContainText(targetNick);
      await expect(alice.chat.nickChangePassword).toBeVisible();

      await alice.chat.confirmNickChange('wrong-password');
      await expect(alice.chat.nickChangeError).toContainText(
        'Incorrect password',
      );
      await alice.chat.expectNickInList(alice.nick);
      await alice.chat.expectNickNotInList(targetNick);

      await alice.chat.confirmNickChange(targetPassword);
      await alice.chat.expectNickInList(targetNick);
      await alice.chat.expectNickNotInList(alice.nick);
    } finally {
      await closeUsers([alice]);
    }
  });

  test('/ns ghost requires the target password and disconnects the stale session (K4)', async ({
    browser,
  }) => {
    const targetNick = uniqueNickname('nsghost');
    const targetPassword = `pw-${Date.now().toString(36)}`;
    const target = await registeredNick(browser, targetNick, targetPassword);
    const requester = await newSignedInUser(browser, 'nsreq');

    try {
      await requester.chat.sendMessage(`/ns ghost ${targetNick} wrong-password`);
      await requester.chat.expectMessageVisible('[NickServ] Invalid password');
      await expect(target.chat.page).toHaveURL(/\/chat(\?.*)?$/);

      await requester.chat.sendMessage(
        `/ns ghost ${targetNick} ${targetPassword}`,
      );
      await requester.chat.expectMessageVisible(
        `[NickServ] Ghost command sent for ${targetNick}`,
      );
      await expect(target.chat.page).toHaveURL(/\/connect(\?.*)?$/, {
        timeout: 10_000,
      });
    } finally {
      await closeUsers([target, requester]);
    }
  });
});
