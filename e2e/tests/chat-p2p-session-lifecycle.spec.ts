import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import {
  openP2PLobbyFromInvite,
  P2PLobbyPage,
} from '../pages/P2PLobbyPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'p2plife',
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

async function openGenericP2PLobbies(alice: TestUser, bob: TestUser) {
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
  await bob.chat.switchToTab(alice.nick);

  const bobLink = bob.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(bobLink).toHaveAttribute('href', inviteHref || '');

  const aliceLobby = await openP2PLobbyFromInvite(alice.page, aliceLink);
  const bobLobby = await openP2PLobbyFromInvite(bob.page, bobLink);

  await expect(aliceLobby.audioCallButton).toBeVisible({ timeout: 10_000 });
  await expect(bobLobby.audioCallButton).toBeVisible({ timeout: 10_000 });

  return { aliceLobby, bobLobby };
}

test.describe('P2P session lifecycle', () => {
  test('closing one open lobby updates the peer lobby without stealing chat focus (Z5)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z5a');
    const bob = await newSignedInUser(browser, 'z5b');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await openGenericP2PLobbies(alice, bob));

      await bob.chat.switchToTab('#lobby');
      await alice.chat.expectTabSelected(bob.nick);
      await bob.chat.expectTabSelected('#lobby');

      const bobLobbyClosed = bobLobby.page.waitForEvent('close');
      await bobLobby.closeSession();
      await bobLobbyClosed;

      await expect(aliceLobby.sessionEnded).toBeVisible({ timeout: 10_000 });
      await expect(aliceLobby.page.getByText('Session closed by user.')).toBeVisible();

      await alice.chat.expectTabSelected(bob.nick);
      await bob.chat.expectTabSelected('#lobby');

      await alice.chat.switchToStatusTab();
      await alice.chat.expectStatusMessageVisible(
        `P2P session with ${bob.nick} ended`,
      );
      await bob.chat.switchToStatusTab();
      await bob.chat.expectStatusMessageVisible(
        `P2P session with ${alice.nick} ended`,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
