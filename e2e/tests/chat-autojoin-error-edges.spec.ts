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

function uniqueChannel(prefix = 'ajerr'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
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

test.describe('Auto-join error edges', () => {
  test('failed autojoin on reconnect reports error and later channels still join (Y9)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'y9own');
    const guest = await newSignedInUser(browser, 'y9guest');
    const lockedChannel = uniqueChannel('y9lock');
    const validChannel = uniqueChannel('y9valid');
    const key = `key${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${lockedChannel}`);
      await owner.chat.expectTabVisible(lockedChannel);
      await owner.chat.sendMessage(`/mode +k ${key}`);
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +k`);

      await guest.chat.sendMessage(`/autojoin add ${lockedChannel} wrong-key`);
      await guest.chat.expectMessageVisible(
        `* Added to auto-join list: ${lockedChannel}`,
      );

      await guest.chat.sendMessage(`/autojoin add ${validChannel}`);
      await guest.chat.expectMessageVisible(
        `* Added to auto-join list: ${validChannel}`,
      );
      await guest.chat.page.waitForTimeout(500);

      await reconnectRegisteredUser(guest);

      await guest.chat.expectTabVisible(validChannel);
      await guest.chat.expectTabSelected('#lobby');
      await guest.chat.expectTabHidden(lockedChannel);

      await guest.chat.switchToStatusTab();
      await guest.chat.expectStatusMessageVisible(
        `* Auto-joining ${lockedChannel}...`,
      );
      await guest.chat.expectStatusMessageVisible('Bad channel key (+k)');
      await guest.chat.expectStatusMessageVisible(
        `* Auto-joining ${validChannel}...`,
      );
    } finally {
      await owner.ctx.close();
      await guest.ctx.close();
    }
  });
});
