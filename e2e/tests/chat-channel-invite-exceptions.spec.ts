import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'invex'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueNickBase(prefix = 'x5ex'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(page: Page, nick: string) {
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
  nick: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, nick);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Channel invite exceptions', () => {
  test('matching invite exception allows invite-only join and removal restores the restriction (X5)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('x5invex');
    const nickBase = uniqueNickBase();
    const owner = await newSignedInUser(browser, `${nickBase}op`);
    const excepted = await newSignedInUser(browser, `${nickBase}ok`);
    const blocked = await newSignedInUser(browser, `${nickBase}no`);
    const exceptionMask = `${excepted.nick}!*@*`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await owner.chat.sendMessage('/mode +i');
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +i`);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.addChannelCentralInviteException(exceptionMask);
      await owner.chat.closeChannelCentral();

      await excepted.chat.sendMessage(`/join ${channel}`);
      await excepted.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(excepted.nick);

      await blocked.chat.sendMessage(`/join ${channel}`);
      await blocked.chat.expectMessageVisible('Channel is invite-only (+i)');
      await blocked.chat.expectTabHidden(channel);

      await excepted.chat.sendMessage(`/part ${channel}`);
      await excepted.chat.expectTabHidden(channel);
      await owner.chat.expectNickNotInList(excepted.nick);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.removeChannelCentralInviteException(exceptionMask);
      await owner.chat.closeChannelCentral();

      await excepted.chat.sendMessage(`/join ${channel}`);
      await excepted.chat.expectMessageVisible('Channel is invite-only (+i)');
      await excepted.chat.expectTabHidden(channel);
    } finally {
      await closeUsers([owner, excepted, blocked]);
    }
  });
});
