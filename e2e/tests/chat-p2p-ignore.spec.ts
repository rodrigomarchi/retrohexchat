import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'p2pignore',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectTitleDoesNotFlash(page: Page, stableTitle: string) {
  await page.waitForTimeout(1_700);
  await expect(page).toHaveTitle(stableTitle);
}

async function p2pCommandSettlementCount(chat: ChatPage, targetNick: string) {
  const sentCount = await chat.messageList
    .getByText(`P2P invite sent to ${targetNick}`, { exact: false })
    .count();
  const unavailableCount = await chat.messageList
    .getByText('User not available', { exact: false })
    .count();

  return sentCount + unavailableCount;
}

async function expectP2PCommandSettled(
  chat: ChatPage,
  targetNick: string,
  previousCount: number,
) {
  await expect
    .poll(async () => p2pCommandSettlementCount(chat, targetNick))
    .toBeGreaterThan(0);
  await expect
    .poll(async () => p2pCommandSettlementCount(chat, targetNick))
    .toBeGreaterThan(previousCount);
}

test.describe('P2P ignored invite filtering', () => {
  test('ignored P2P sender does not open PM invite card or notification (Z2)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z2a');
    const bob = await newSignedInUser(browser, 'z2b');

    try {
      await bob.chat.sendMessage(`/ignore ${alice.nick} invites`);
      await bob.chat.expectMessageVisible(
        `* ${alice.nick} is now ignored (invites)`,
      );
      await bob.chat.expectTabSelected('#lobby');

      const stableTitle = await bob.chat.page.title();

      const previousSettlementCount = await p2pCommandSettlementCount(
        alice.chat,
        bob.nick,
      );
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await expectP2PCommandSettled(
        alice.chat,
        bob.nick,
        previousSettlementCount,
      );

      await bob.chat.page.waitForTimeout(500);
      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabHidden(alice.nick);
      await expect(bob.chat.pmConversationItem(alice.nick)).toHaveCount(0);
      await expect(bob.chat.p2pInviteCard()).toHaveCount(0);
      await expectTitleDoesNotFlash(bob.chat.page, stableTitle);

      await bob.chat.switchToStatusTab();
      await bob.chat.expectStatusMessageHidden(`P2P invite from ${alice.nick}`);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('message-only ignore does not suppress P2P invite delivery (Z2)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z2ma');
    const bob = await newSignedInUser(browser, 'z2mb');

    try {
      await bob.chat.sendMessage(`/ignore ${alice.nick} messages`);
      await bob.chat.expectMessageVisible(
        `* ${alice.nick} is now ignored (messages)`,
      );
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );

      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.switchToTab(alice.nick);
      await expect(bob.chat.p2pInviteCard()).toBeVisible();
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
