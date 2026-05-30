import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import { openP2PLobbyFromInvite, P2PLobbyPage } from '../pages/P2PLobbyPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'p2pcancel',
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

  return { chat, ctx, page, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectSessionEndedStatus(chat: ChatPage, peerNick: string) {
  await chat.switchToStatusTab();
  await chat.expectStatusMessageVisible(`P2P session with ${peerNick} ended`);
  await chat.expectStatusMessageVisible('closed by user');
}

test.describe('P2P invite cancellation', () => {
  test('closing a pending invite notifies both chats and stale invite opens ended state (Z3)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z3a');
    const bob = await newSignedInUser(browser, 'z3b');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobExpiredPage: Page | undefined;

    try {
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );

      const aliceLink = alice.chat
        .p2pInviteCard()
        .getByRole('link', { name: 'Join lobby' });
      await expect(aliceLink).toHaveAttribute('href', /^\/p2p\/[A-Za-z0-9_-]+$/);
      const inviteHref = await aliceLink.getAttribute('href');

      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.expectTabSelected('#lobby');

      aliceLobby = await openP2PLobbyFromInvite(alice.page, aliceLink);
      const aliceLobbyClosed = aliceLobby.page.waitForEvent('close');
      await aliceLobby.closeSession();
      await aliceLobbyClosed;

      await expectSessionEndedStatus(alice.chat, bob.nick);
      await expectSessionEndedStatus(bob.chat, alice.nick);

      await bob.chat.switchToTab(alice.nick);
      const staleLink = bob.chat
        .p2pInviteCard()
        .getByRole('link', { name: 'Join lobby' });
      await expect(staleLink).toHaveAttribute('href', inviteHref || '');

      const bobPopup = bob.page.waitForEvent('popup');
      await staleLink.click();
      bobExpiredPage = await bobPopup;

      await expect(bobExpiredPage.getByText('P2P Session Ended')).toBeVisible();
      await expect(bobExpiredPage.getByText('Session closed by user.')).toBeVisible();
    } finally {
      await bobExpiredPage?.close().catch(() => {});
      await aliceLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
