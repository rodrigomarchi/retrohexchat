import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { mkdtemp, rm, truncate, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
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
  prefix = 'p2pfl',
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

test.describe('P2P file transfer limits', () => {
  test('blocked extensions show a validation error and do not create a receiver offer (Z9)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z9ba');
    const bob = await newSignedInUser(browser, 'z9bb');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await openSendFileLobbies(alice, bob));

      await aliceLobby.fileInput.setInputFiles({
        name: 'z9-blocked.exe',
        mimeType: 'application/octet-stream',
        buffer: Buffer.from('not an executable'),
      });

      await aliceLobby.expectFileValidationError(
        /(Blocked file type|Tipo de arquivo bloqueado): \.exe/i,
      );
      await expect(bobLobby.fileTransfer).toHaveCount(0);
      await expect(bobLobby.fileTransferAcceptButton).toHaveCount(0);

      const validFileName = 'z9-after-blocked.txt';
      await aliceLobby.fileInput.setInputFiles({
        name: validFileName,
        mimeType: 'text/plain',
        buffer: Buffer.from('valid after blocked extension'),
      });

      await expect(bobLobby.fileTransfer).toContainText(validFileName, {
        timeout: 10_000,
      });
      await expect(bobLobby.fileTransferAcceptButton).toBeVisible();
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });

  test('oversized files show the configured size limit and do not create a receiver offer (Z9)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z9sa');
    const bob = await newSignedInUser(browser, 'z9sb');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;
    let tempDir: string | undefined;

    try {
      ({ aliceLobby, bobLobby } = await openSendFileLobbies(alice, bob));

      tempDir = await mkdtemp(join(tmpdir(), 'retro-hex-z9-'));
      const oversizedPath = join(tempDir, 'z9-oversized.bin');
      await writeFile(oversizedPath, '');
      await truncate(oversizedPath, 500 * 1024 * 1024 + 1);

      await aliceLobby.fileInput.setInputFiles(oversizedPath);

      await aliceLobby.expectFileValidationError(/(500 MB limit|limite de 500 MB)/i);
      await expect(bobLobby.fileTransfer).toHaveCount(0);
      await expect(bobLobby.fileTransferAcceptButton).toHaveCount(0);
    } finally {
      if (tempDir) {
        await rm(tempDir, { recursive: true, force: true });
      }
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
