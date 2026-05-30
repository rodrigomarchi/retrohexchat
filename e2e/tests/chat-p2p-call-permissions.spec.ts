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

async function installDeniedMedia(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
    const mediaDevices = {
      getUserMedia: async () => {
        throw new DOMException('Permission denied', 'NotAllowedError');
      },
      enumerateDevices: async () => [],
      addEventListener: () => {},
      removeEventListener: () => {},
    };

    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: mediaDevices,
    });
  });
}

async function newSignedInDeniedMediaUser(
  browser: Browser,
  prefix = 'p2pdeny',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  await installDeniedMedia(ctx);

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

async function createDeniedCallLobbies(alice: TestUser, bob: TestUser) {
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

test.describe('P2P call media permissions', () => {
  test('denied microphone permission shows actionable error and leaves chat usable (Z6)', async ({
    browser,
  }) => {
    const alice = await newSignedInDeniedMediaUser(browser, 'z6a');
    const bob = await newSignedInDeniedMediaUser(browser, 'z6b');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await createDeniedCallLobbies(alice, bob));

      await bobLobby.acceptAction('audio_call');

      const permissionText =
        'Microphone permission denied. Enable microphone permission in your browser and try again.';
      await expect(aliceLobby.page.getByText(permissionText)).toHaveCount(1, {
        timeout: 10_000,
      });
      await expect(bobLobby.page.getByText(permissionText)).toHaveCount(1, {
        timeout: 10_000,
      });
      await expect(aliceLobby.closeSessionButton).toBeVisible();
      await expect(bobLobby.closeSessionButton).toBeVisible();

      const pmText = `chat usable after denied media ${Date.now()}`;
      await alice.chat.sendMessage(pmText);
      await alice.chat.expectMessageVisible(pmText);
      await bob.chat.switchToTab(alice.nick);
      await bob.chat.expectMessageVisible(pmText);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
