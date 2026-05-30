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
  prefix = 'aa3',
): Promise<TestUser> {
  const ctx = await browser.newContext({ acceptDownloads: true });
  const page = await ctx.newPage();
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

  await aliceLobby.waitUntilLiveViewConnected();
  await bobLobby.waitUntilLiveViewConnected();
  await expect(aliceLobby.sendFileButton).toBeVisible({ timeout: 10_000 });
  await expect(bobLobby.sendFileButton).toBeVisible({ timeout: 10_000 });

  return { aliceLobby, bobLobby };
}

test.describe('Reconnect P2P state', () => {
  test('browser offline/online while P2P lobby is open keeps both peers coherent (AA3)', async ({
    browser,
  }) => {
    test.setTimeout(60_000);

    const alice = await newSignedInUser(browser, 'aa3a');
    const bob = await newSignedInUser(browser, 'aa3b');
    const lobbyMessage = `aa3 lobby message ${Date.now()}`;
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await openGenericP2PLobbies(alice, bob));

      await bob.ctx.setOffline(true);
      await bobLobby.waitUntilBrowserOffline();
      await expect(aliceLobby.root).toBeVisible();
      await expect(aliceLobby.sessionEnded).toHaveCount(0);

      await bob.ctx.setOffline(false);
      await bobLobby.waitUntilBrowserOnline();
      await bobLobby.waitUntilLiveViewConnected();
      await bobLobby.waitUntilOpen();
      await expect(bobLobby.sessionEnded).toHaveCount(0);
      await expect(aliceLobby.closeSessionButton).toBeVisible();
      await expect(bobLobby.closeSessionButton).toBeVisible();

      await bobLobby.sendLobbyMessage(lobbyMessage);
      await aliceLobby.expectLobbyMessage(lobbyMessage);

      await aliceLobby.sendFileButton.click();
      await bobLobby.acceptAction('file_transfer');

      await expect(aliceLobby.fileTransferHook).toBeVisible({ timeout: 20_000 });
      await expect(bobLobby.fileTransferHook).toBeVisible({ timeout: 20_000 });
      await alice.chat.expectTabSelected(bob.nick);
      await bob.chat.expectTabSelected(alice.nick);
    } finally {
      await bob.ctx.setOffline(false).catch(() => {});
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
