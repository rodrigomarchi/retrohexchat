import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  connect: ConnectPage;
  ctx: BrowserContext;
  nick: string;
  password: string;
};

function uniqueAlias(prefix = 'autoalias'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

function uniqueChannel(prefix = 'autocomp'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueTimer(prefix = 'autocomp'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix: string,
  password = 'pass12345',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, nick, password };
}

async function reconnectRegisteredUser(user: TestUser) {
  await user.chat.disconnect();
  await user.connect.open();
  await user.connect.enterNickname(user.nick);
  await user.connect.authenticateWithPassword(user.password);
  await user.chat.waitUntilConnected();
}

test.describe('Automation composition', () => {
  test('aliases expand consistently inside timer, perform, and autorespond commands (Y11)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'y11own');
    const visitor = await newSignedInUser(browser, 'y11vis');
    const timerAlias = uniqueAlias('tm');
    const performAlias = uniqueAlias('pf');
    const respondAlias = uniqueAlias('ar');
    const timerName = uniqueTimer('y11');
    const channel = uniqueChannel('y11ar');
    const timerMarker = `alias-timer-${Date.now()}`;
    const performMarker = `alias-perform-${Date.now()}`;
    const respondMarker = `alias-autorespond-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/alias add ${timerAlias} /me ${timerMarker}`);
      await owner.chat.expectMessageVisible(`* Alias /${timerAlias} created`);

      await owner.chat.sendMessage(
        `/alias add ${performAlias} /me ${performMarker}`,
      );
      await owner.chat.expectMessageVisible(`* Alias /${performAlias} created`);

      await owner.chat.sendMessage(
        `/alias add ${respondAlias} /notice $1 ${respondMarker}`,
      );
      await owner.chat.expectMessageVisible(`* Alias /${respondAlias} created`);

      await owner.chat.sendMessage(`/timer ${timerName} 1 /${timerAlias}`);
      await owner.chat.expectMessageVisible(`* Timer '${timerName}' set`);
      await owner.chat.expectMessageVisible(timerMarker, 5_000);

      await owner.chat.sendMessage(`/perform add /${performAlias}`);
      await owner.chat.expectMessageVisible(
        `* Added to perform list: /${performAlias}`,
      );
      await owner.chat.page.waitForTimeout(500);

      await reconnectRegisteredUser(owner);
      await owner.chat.expectMessageVisible(performMarker, 5_000);

      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await owner.chat.sendMessage(
        `/autorespond add on_join ${channel} /${respondAlias} $nick`,
      );
      await owner.chat.expectMessageVisible('Auto-respond rule added: on_join');

      await visitor.chat.sendMessage(`/join ${channel}`);
      await visitor.chat.expectTabVisible(channel);
      await visitor.chat.expectMessageVisible(respondMarker, 15_000);
    } finally {
      await owner.chat.sendMessage('/autorespond remove 0').catch(() => {});
      await owner.ctx.close();
      await visitor.ctx.close();
    }
  });
});
