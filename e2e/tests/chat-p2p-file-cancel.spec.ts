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
  prefix = 'p2pfc',
): Promise<TestUser> {
  const ctx = await browser.newContext({ acceptDownloads: true });
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

async function openSendFileLobbies(alice: TestUser, bob: TestUser) {
  await alice.chat.sendMessage(`/sendfile ${bob.nick}`);
  await alice.chat.expectTabVisible(bob.nick);
  await alice.chat.expectTabSelected(bob.nick);
  await alice.chat.expectMessageVisible(
    `P2P invite sent to ${bob.nick}. Waiting for response...`,
  );
  await alice.chat.expectMessageVisible('File transfer started');

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

  await bobLobby.acceptAction('file_transfer');
  await expect(aliceLobby.fileTransferHook).toBeVisible({ timeout: 20_000 });
  await expect(bobLobby.fileTransferHook).toBeVisible({ timeout: 20_000 });

  return { aliceLobby, bobLobby };
}

test.describe('P2P file transfer cancellation', () => {
  test('cancelling an offered file before receiver accepts updates both peers (Z8)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z8oa');
    const bob = await newSignedInUser(browser, 'z8ob');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await openSendFileLobbies(alice, bob));

      const fileName = 'z8-offered-cancel.txt';
      await aliceLobby.fileInput.setInputFiles({
        name: fileName,
        mimeType: 'text/plain',
        buffer: Buffer.from(`cancel before upload from ${alice.nick}`),
      });

      await expect(aliceLobby.fileTransfer).toContainText(fileName, {
        timeout: 10_000,
      });
      await expect(bobLobby.fileTransfer).toContainText(fileName, {
        timeout: 10_000,
      });
      await expect(bobLobby.fileTransferAcceptButton).toBeVisible({
        timeout: 10_000,
      });

      await aliceLobby.fileTransferCancelButton.click();

      await aliceLobby.expectFileCancelled(fileName);
      await bobLobby.expectFileCancelled(fileName);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });

  test('cancelling after transfer starts updates both peers without completing download (Z8)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z8ta');
    const bob = await newSignedInUser(browser, 'z8tb');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await openSendFileLobbies(alice, bob));

      const fileName = 'z8-transferring-cancel.bin';
      await aliceLobby.fileInput.setInputFiles({
        name: fileName,
        mimeType: 'application/octet-stream',
        buffer: Buffer.alloc(32 * 1024 * 1024, 0x5a),
      });

      await expect(bobLobby.fileTransferAcceptButton).toBeVisible({
        timeout: 15_000,
      });
      await bobLobby.fileTransferAcceptButton.click();

      await expect(aliceLobby.fileTransfer).toContainText('%', {
        timeout: 10_000,
      });
      await aliceLobby.fileTransferCancelButton.click();

      await aliceLobby.expectFileCancelled(fileName);
      await bobLobby.expectFileCancelled(fileName);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
