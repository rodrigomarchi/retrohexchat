import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'ctxmenu'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'ctx') {
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
  prefix = 'ctx',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'ctxa');
  const bob = await newSignedInUser(browser, 'ctxb');

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);

  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);

  await alice.chat.switchToTab(channel);
  await alice.chat.expectNickInList(bob.nick);
  await bob.chat.expectNickInList(alice.nick);

  return { alice, bob };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Chat context menus', () => {
  test('nicklist context menu opens PM, shows whois, toggles ignore, and grants voice/op (O12)', async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const ignoredText = `ctx-ignore-hidden-${Date.now()}`;
    const restoredText = `ctx-ignore-restored-${Date.now()}`;

    try {
      await alice.chat.openNicklistContextMenu(bob.nick);
      await expect(alice.chat.nicklistContextQueryMenuItem).toBeVisible();
      await expect(alice.chat.nicklistContextWhoisMenuItem).toBeVisible();
      await expect(alice.chat.nicklistContextIgnoreMenuItem).toBeVisible();
      await expect(alice.chat.nicklistContextVoiceMenuItem).toBeVisible();
      await expect(alice.chat.nicklistContextOpMenuItem).toBeVisible();

      await alice.chat.nicklistContextQueryMenuItem.click();
      await expect(alice.chat.nicklistContextMenu).toBeHidden();
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);

      await alice.chat.switchToTab(channel);
      await alice.chat.openNicklistContextMenu(bob.nick);
      await alice.chat.nicklistContextWhoisMenuItem.click();
      await alice.chat.expectMessageVisible(`----- Whois: ${bob.nick} -----`);
      await alice.chat.expectMessageVisible(`Shared channels: ${channel}`);

      await alice.chat.openNicklistContextMenu(bob.nick);
      await alice.chat.nicklistContextIgnoreMenuItem.click();
      await alice.chat.expectMessageVisible(`* ${bob.nick} is now ignored`);

      await bob.chat.sendMessage(ignoredText);
      await alice.chat.expectMessageHidden(ignoredText);

      await alice.chat.openNicklistContextMenu(bob.nick);
      await expect(alice.chat.nicklistContextUnignoreMenuItem).toBeVisible();
      await alice.chat.nicklistContextUnignoreMenuItem.click();
      await alice.chat.expectMessageVisible(`* ${bob.nick} is no longer ignored`);

      await bob.chat.sendMessage(restoredText);
      await alice.chat.expectMessageVisible(restoredText);

      await alice.chat.openNicklistContextMenu(bob.nick);
      await alice.chat.nicklistContextVoiceMenuItem.click();
      await alice.chat.expectNickRole(bob.nick, 'voiced');
      await bob.chat.expectNickRole(bob.nick, 'voiced');

      await alice.chat.openNicklistContextMenu(bob.nick);
      await alice.chat.nicklistContextOpMenuItem.click();
      await alice.chat.expectNickRole(bob.nick, 'operator');
      await bob.chat.expectNickRole(bob.nick, 'operator');
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
