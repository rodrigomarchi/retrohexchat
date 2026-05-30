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

async function installMockMedia(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
    const mediaDevices = {
      getUserMedia: async () => new MediaStream(),
      enumerateDevices: async () => [
        {
          deviceId: 'mock-mic',
          groupId: 'mock-group',
          kind: 'audioinput',
          label: 'Mock Microphone',
          toJSON() {
            return this;
          },
        },
        {
          deviceId: 'mock-camera',
          groupId: 'mock-group',
          kind: 'videoinput',
          label: 'Mock Camera',
          toJSON() {
            return this;
          },
        },
      ],
      addEventListener: () => {},
      removeEventListener: () => {},
    };

    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: mediaDevices,
    });
  });
}

async function newSignedInMediaUser(
  browser: Browser,
  prefix = 'p2pctrl',
): Promise<TestUser> {
  const ctx = await browser.newContext({
    permissions: ['microphone', 'camera'],
  });
  await installMockMedia(ctx);

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

  await expect(aliceLobby.videoCallButton).toBeVisible({ timeout: 10_000 });
  await expect(bobLobby.videoCallButton).toBeVisible({ timeout: 10_000 });

  return { aliceLobby, bobLobby };
}

test.describe('P2P call controls', () => {
  test('mute and camera toggles update local controls and remote indicators (Z7)', async ({
    browser,
  }) => {
    const alice = await newSignedInMediaUser(browser, 'z7a');
    const bob = await newSignedInMediaUser(browser, 'z7b');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await openGenericP2PLobbies(alice, bob));

      await aliceLobby.videoCallButton.click();
      await expect(bobLobby.actionRequest('video_call')).toBeVisible({
        timeout: 10_000,
      });
      await bobLobby.acceptAction('video_call');

      await expect(aliceLobby.mediaCall).toBeVisible({ timeout: 20_000 });
      await expect(bobLobby.mediaCall).toBeVisible({ timeout: 20_000 });
      await expect(aliceLobby.muteButton).toHaveAttribute('title', 'Mute');
      await expect(aliceLobby.cameraButton).toHaveAttribute('title', 'Camera Off');

      await aliceLobby.muteButton.click();
      await expect(aliceLobby.muteButton).toHaveAttribute('title', 'Unmute');
      await expect(bobLobby.peerMutedIndicator).toBeVisible({
        timeout: 10_000,
      });

      await aliceLobby.cameraButton.click();
      await expect(aliceLobby.cameraButton).toHaveAttribute('title', 'Camera On');
      await expect(bobLobby.peerCameraOffIndicator).toBeVisible({
        timeout: 10_000,
      });

      await aliceLobby.muteButton.click();
      await expect(aliceLobby.muteButton).toHaveAttribute('title', 'Mute');
      await expect(bobLobby.peerMutedIndicator).toHaveCount(0);

      await aliceLobby.cameraButton.click();
      await expect(aliceLobby.cameraButton).toHaveAttribute('title', 'Camera Off');
      await expect(bobLobby.peerCameraOffIndicator).toHaveCount(0);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
