import {
  Browser,
  BrowserContext,
  Locator,
  Page,
  expect,
  test,
} from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'idlepassive') {
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
  prefix = 'idlepassive',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function openMenuItem(trigger: Locator, item: Locator) {
  await trigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

async function waitForIdleMinute(chat: ChatPage) {
  await chat.page.waitForTimeout(65_000);
}

function latestIdleRow(chat: ChatPage) {
  return chat.messageRows.filter({ hasText: 'Idle for:' }).last();
}

async function expectLatestIdle(chat: ChatPage, text: string) {
  await expect(latestIdleRow(chat)).toContainText(`Idle for: ${text}`);
}

test.describe('Idle passive interactions', () => {
  test('switching tabs, opening dialogs, and hovering nicklist do not reset idle (W11)', async ({
    browser,
  }) => {
    test.setTimeout(180_000);

    const alice = await newSignedInUser(browser, 'w11a');
    const bob = await newSignedInUser(browser, 'w11b');

    try {
      await alice.chat.expectNickInList(bob.nick);
      await bob.chat.expectNickInList(alice.nick);

      await waitForIdleMinute(bob.chat);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await expectLatestIdle(alice.chat, '1 minute');

      await bob.chat.switchToStatusTab();
      await bob.chat.switchToTab('#lobby');

      await openMenuItem(bob.chat.helpMenuTrigger, bob.chat.aboutMenuItem);
      await expect(bob.chat.aboutDialog).toBeVisible();
      await bob.chat.aboutOkButton.click();
      await expect(bob.chat.aboutDialog).toBeHidden();

      await bob.chat.openNickHoverCard(alice.nick);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await expectLatestIdle(alice.chat, '1 minute');
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
