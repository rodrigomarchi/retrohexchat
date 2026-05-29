import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import {
  P2PLobbyPage,
  openP2PLobbyFromInvite,
} from '../pages/P2PLobbyPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'p2pi',
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

test.describe('P2P invite flow', () => {
  test('/p2p creates PM invite cards and both users can open the lobby (N4)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'p2pia');
    const bob = await newSignedInUser(browser, 'p2pib');
    let aliceLobby: Page | undefined;
    let bobLobby: Page | undefined;

    try {
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );

      const aliceCard = alice.chat.p2pInviteCard();
      await expect(aliceCard).toBeVisible();
      const aliceLink = aliceCard.getByRole('link', { name: 'Join lobby' });
      await expect(aliceLink).toHaveAttribute('href', /^\/p2p\/[A-Za-z0-9_-]+$/);
      const inviteHref = await aliceLink.getAttribute('href');

      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.switchToTab(alice.nick);

      const bobCard = bob.chat.p2pInviteCard();
      await expect(bobCard).toBeVisible();
      const bobLink = bobCard.getByRole('link', { name: 'Join lobby' });
      await expect(bobLink).toHaveAttribute('href', inviteHref || '');

      const bobPopup = bob.page.waitForEvent('popup');
      await bobLink.click();
      bobLobby = await bobPopup;
      await expect(bobLobby).toHaveURL(/\/p2p\/[A-Za-z0-9_-]+$/);
      await expect(bobLobby.getByTestId('p2p-lobby')).toBeVisible();

      const alicePopup = alice.page.waitForEvent('popup');
      await aliceLink.click();
      aliceLobby = await alicePopup;
      await expect(aliceLobby).toHaveURL(/\/p2p\/[A-Za-z0-9_-]+$/);
      await expect(aliceLobby.getByTestId('p2p-lobby')).toBeVisible();

      await expect(aliceLobby.getByRole('button', { name: 'Audio Call' })).toBeVisible({
        timeout: 10_000,
      });
      await expect(bobLobby.getByRole('button', { name: 'Audio Call' })).toBeVisible({
        timeout: 10_000,
      });

      await bobLobby.getByRole('button', { name: 'Close Session' }).click();
      await expect(aliceLobby.getByTestId('p2p-session-ended')).toBeVisible({
        timeout: 10_000,
      });
    } finally {
      await aliceLobby?.close().catch(() => {});
      await bobLobby?.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });

  test('declining a P2P action clears consent without stealing chat focus (N8)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'p2pda');
    const bob = await newSignedInUser(browser, 'p2pdb');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      await alice.chat.sendMessage(`/call ${bob.nick}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );
      await alice.chat.expectMessageVisible('Audio call started');

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

      aliceLobby = await openP2PLobbyFromInvite(alice.page, aliceLink);
      bobLobby = await openP2PLobbyFromInvite(bob.page, bobLink);

      await bob.chat.switchToTab('#lobby');
      await bobLobby.declineAction('audio_call');

      await expect(aliceLobby.actionRequest('audio_call')).toHaveCount(0);
      await expect(bobLobby.actionRequest('audio_call')).toHaveCount(0);
      await expect(aliceLobby.page.getByText('audio_call request declined.')).toBeVisible({
        timeout: 10_000,
      });
      await expect(bobLobby.page.getByText('audio_call request declined.')).toBeVisible({
        timeout: 10_000,
      });
      await expect(aliceLobby.mediaCall).toHaveCount(0);
      await expect(bobLobby.mediaCall).toHaveCount(0);
      await expect(aliceLobby.audioCallButton).toBeVisible();
      await expect(bobLobby.audioCallButton).toBeVisible();
      await bob.chat.expectTabSelected('#lobby');
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
