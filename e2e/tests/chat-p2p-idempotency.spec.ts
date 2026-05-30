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
      getUserMedia: async () => {
        return new MediaStream();
      },
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
  prefix = 'p2pidem',
): Promise<TestUser> {
  const ctx = await browser.newContext({
    permissions: ['microphone'],
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

async function createCallLobbies(alice: TestUser, bob: TestUser) {
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

  const aliceLobby = await openP2PLobbyFromInvite(alice.page, aliceLink);
  const bobLobby = await openP2PLobbyFromInvite(bob.page, bobLink);

  await expect(bobLobby.actionRequest('audio_call')).toBeVisible({
    timeout: 10_000,
  });

  return { aliceLobby, bobLobby };
}

async function expectSingleFeedback(lobby: P2PLobbyPage, text: string) {
  await expect(lobby.page.getByText(text)).toHaveCount(1, {
    timeout: 10_000,
  });
}

test.describe('P2P action response idempotency', () => {
  test('double-clicking Accept settles the action once without duplicate state (Z4)', async ({
    browser,
  }) => {
    const alice = await newSignedInMediaUser(browser, 'z4aa');
    const bob = await newSignedInMediaUser(browser, 'z4ab');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await createCallLobbies(alice, bob));

      await bobLobby.doubleAcceptAction('audio_call');

      await expectSingleFeedback(aliceLobby, 'audio_call request accepted.');
      await expectSingleFeedback(bobLobby, 'audio_call request accepted.');
      await expect(aliceLobby.mediaCall).toBeVisible({ timeout: 20_000 });
      await expect(bobLobby.mediaCall).toBeVisible({ timeout: 20_000 });
      await expect(aliceLobby.actionRequest('audio_call')).toHaveCount(0);
      await expect(bobLobby.actionRequest('audio_call')).toHaveCount(0);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });

  test('double-clicking Decline clears the action once and leaves the lobby usable (Z4)', async ({
    browser,
  }) => {
    const alice = await newSignedInMediaUser(browser, 'z4da');
    const bob = await newSignedInMediaUser(browser, 'z4db');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await createCallLobbies(alice, bob));

      await bobLobby.doubleDeclineAction('audio_call');

      await expectSingleFeedback(aliceLobby, 'audio_call request declined.');
      await expectSingleFeedback(bobLobby, 'audio_call request declined.');
      await expect(aliceLobby.mediaCall).toHaveCount(0);
      await expect(bobLobby.mediaCall).toHaveCount(0);
      await expect(aliceLobby.actionRequest('audio_call')).toHaveCount(0);
      await expect(bobLobby.actionRequest('audio_call')).toHaveCount(0);
      await expect(aliceLobby.audioCallButton).toBeVisible();
      await expect(bobLobby.audioCallButton).toBeVisible();
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
