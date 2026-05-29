import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx?: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'win'): string {
  return `#z${prefix}${Date.now().toString(36)}${Math.random()
    .toString(36)
    .slice(2, 6)}`;
}

async function signedInUser(page: Page, prefix = 'win') {
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
  prefix = 'win',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { ...user, ctx };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx?.close()));
}

async function pressCtrlShift(page: Page, key: string) {
  await page.keyboard.down('Control');
  await page.keyboard.down('Shift');
  await page.keyboard.press(key);
  await page.keyboard.up('Shift');
  await page.keyboard.up('Control');
}

test.describe('Window switch shortcuts', () => {
  test('skip Status and cycle channels and PMs in stable order (T9)', async ({
    browser,
    page,
  }) => {
    const aliceUser = await signedInUser(page, 'wina');
    const alice: TestUser = { ...aliceUser };
    const bob = await newSignedInUser(browser, 'winb');
    const channel = uniqueChannel();

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabSelected(channel);
      await alice.chat.sendMessage(`/msg ${bob.nick} shortcut hello`);
      await alice.chat.expectTabVisible(bob.nick);

      await alice.chat.switchToStatusTab();
      await pressCtrlShift(page, ']');
      await alice.chat.expectTabSelected('Status');

      await alice.chat.switchToTab('#lobby');
      await pressCtrlShift(page, ']');
      await alice.chat.expectTabSelected(channel);

      await pressCtrlShift(page, ']');
      await alice.chat.expectTabSelected(bob.nick);

      await pressCtrlShift(page, ']');
      await alice.chat.expectTabSelected('#lobby');

      await pressCtrlShift(page, '[');
      await alice.chat.expectTabSelected(bob.nick);

      await pressCtrlShift(page, '1');
      await alice.chat.expectTabSelected('#lobby');
      await pressCtrlShift(page, '2');
      await alice.chat.expectTabSelected(channel);
      await pressCtrlShift(page, '3');
      await alice.chat.expectTabSelected(bob.nick);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
