import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

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
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (window as any).__mockGetUserMediaCalls =
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          ((window as any).__mockGetUserMediaCalls || 0) + 1;
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
  prefix = 'p2pc',
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

async function openLobbyFromInvite(page: Page, link = page.getByRole('link', { name: 'Join lobby' }).first()) {
  const popupPromise = page.waitForEvent('popup');
  await link.click();
  const lobby = await popupPromise;
  await expect(lobby).toHaveURL(/\/p2p\/[A-Za-z0-9_-]+$/);
  await expect(lobby.getByTestId('p2p-lobby')).toBeVisible();
  return lobby;
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('P2P audio calls', () => {
  test('/call creates an audio-call lobby and initializes media on both sides (N5)', async ({
    browser,
  }) => {
    const alice = await newSignedInMediaUser(browser, 'p2pca');
    const bob = await newSignedInMediaUser(browser, 'p2pcb');
    let aliceLobby: Page | undefined;
    let bobLobby: Page | undefined;

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

      const bobLink = bob.chat.p2pInviteCard().getByRole('link', {
        name: 'Join lobby',
      });
      await expect(bobLink).toHaveAttribute('href', inviteHref || '');

      aliceLobby = await openLobbyFromInvite(alice.page, aliceLink);
      bobLobby = await openLobbyFromInvite(bob.page, bobLink);

      await expect(bobLobby.getByText('Action Request: audio_call')).toBeVisible({
        timeout: 10_000,
      });
      await bobLobby.getByRole('button', { name: 'Accept' }).click();

      await expect(aliceLobby.getByTestId('media-call')).toBeVisible({
        timeout: 20_000,
      });
      await expect(bobLobby.getByTestId('media-call')).toBeVisible({
        timeout: 20_000,
      });
      await expect(aliceLobby.getByTestId('media-controls-mute')).toBeVisible();
      await expect(bobLobby.getByTestId('media-controls-mute')).toBeVisible();

      await expect
        .poll(() =>
          aliceLobby!.evaluate(
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            () => (window as any).__mockGetUserMediaCalls || 0,
          ),
        )
        .toBeGreaterThan(0);
      await expect
        .poll(() =>
          bobLobby!.evaluate(
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            () => (window as any).__mockGetUserMediaCalls || 0,
          ),
        )
        .toBeGreaterThan(0);
    } finally {
      await aliceLobby?.close().catch(() => {});
      await bobLobby?.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
