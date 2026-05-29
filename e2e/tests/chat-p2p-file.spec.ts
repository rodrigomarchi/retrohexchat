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
  prefix = 'p2pf',
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

test.describe('P2P file transfer', () => {
  test('/sendfile creates a file-transfer lobby and sends a small file (N6)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'p2pfa');
    const bob = await newSignedInUser(browser, 'p2pfb');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
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

      aliceLobby = await openP2PLobbyFromInvite(alice.page, aliceLink);
      bobLobby = await openP2PLobbyFromInvite(bob.page, bobLink);

      await bobLobby.acceptAction('file_transfer');

      await expect(aliceLobby.fileTransferHook).toBeVisible({ timeout: 20_000 });
      await expect(bobLobby.fileTransferHook).toBeVisible({ timeout: 20_000 });

      const fileName = 'n6-transfer.txt';
      await aliceLobby.fileInput.setInputFiles({
        name: fileName,
        mimeType: 'text/plain',
        buffer: Buffer.from(`hello from ${alice.nick} to ${bob.nick}`),
      });

      await expect(aliceLobby.fileTransfer).toContainText(fileName, {
        timeout: 10_000,
      });
      await expect(aliceLobby.fileTransfer).toContainText('Pending', {
        timeout: 10_000,
      });
      await expect(bobLobby.fileTransfer).toContainText(fileName, {
        timeout: 10_000,
      });
      await expect(bobLobby.fileTransferAcceptButton).toBeVisible({
        timeout: 10_000,
      });

      const downloadPromise = bobLobby.page.waitForEvent('download', {
        timeout: 20_000,
      });
      const aliceClosed = aliceLobby.page.waitForEvent('close', {
        timeout: 20_000,
      });
      const bobClosed = bobLobby.page.waitForEvent('close', {
        timeout: 20_000,
      });

      await bobLobby.fileTransferAcceptButton.click();

      const download = await downloadPromise;
      expect(download.suggestedFilename()).toBe(fileName);
      await aliceClosed;
      await bobClosed;
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
