import { expect, test } from '@playwright/test';
import { uniqueChannel } from '../helpers/chatUsers';
import {
  closeP2PUsers,
  newP2PUser,
  openGameSessionsFromCommand,
  openP2PLobbiesFromCommand,
  openP2PLobbiesFromInviteCards,
} from '../helpers/p2pFlows';
import { P2PLobbyPage } from '../pages/P2PLobbyPage';
import { GameSessionPage } from '../pages/GameSessionPage';

async function joinSharedChannel(
  alice: Awaited<ReturnType<typeof newP2PUser>>,
  bob: Awaited<ReturnType<typeof newP2PUser>>,
  channel: string,
) {
  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);
  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);
}

async function completeTextFileTransfer(
  senderLobby: P2PLobbyPage,
  receiverLobby: P2PLobbyPage,
  fileName: string,
  contents: string,
) {
  await senderLobby.fileInput.setInputFiles({
    name: fileName,
    mimeType: 'text/plain',
    buffer: Buffer.from(contents),
  });

  await expect(senderLobby.fileTransfer).toContainText(fileName, {
    timeout: 10_000,
  });
  await expect(receiverLobby.fileTransfer).toContainText(fileName, {
    timeout: 10_000,
  });
  await expect(receiverLobby.fileTransferAcceptButton).toBeVisible({
    timeout: 10_000,
  });

  const downloadPromise = receiverLobby.page.waitForEvent('download', {
    timeout: 20_000,
  });
  const senderClosed = senderLobby.page.waitForEvent('close', {
    timeout: 20_000,
  });
  const receiverClosed = receiverLobby.page.waitForEvent('close', {
    timeout: 20_000,
  });

  await receiverLobby.fileTransferAcceptButton.click();

  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe(fileName);
  await senderClosed;
  await receiverClosed;
}

async function expectWindowFlagUnset(lobby: P2PLobbyPage, flag: string) {
  await expect
    .poll(() =>
      lobby.page.evaluate((flagName) => {
        const unsafeWindow = window as unknown as Record<string, unknown>;
        return Boolean(unsafeWindow[flagName]);
      }, flag),
    )
    .toBe(false);
}

test.describe('P2P complete user journeys', () => {
  test('nicklist P2P session supports lobby chat, declined action retry, and reverse file transfer (Z13)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const channel = uniqueChannel('z13ctx');
    const alice = await newP2PUser(browser, 'z13a', { acceptDownloads: true });
    const bob = await newP2PUser(browser, 'z13b', { acceptDownloads: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);

      await alice.chat.switchToTab(channel);
      await alice.chat.expectNickInList(bob.nick);
      await alice.chat.openNicklistContextMenu(bob.nick);
      await expect(alice.chat.nicklistContextP2PMenuItem).toBeVisible();
      await alice.chat.nicklistContextP2PMenuItem.click();

      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );

      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromInviteCards(
          alice,
          bob,
          /^\/p2p\/[A-Za-z0-9_-]+$/,
        ));

      await expect(aliceLobby.audioCallButton).toBeVisible({ timeout: 10_000 });
      await expect(bobLobby.audioCallButton).toBeVisible({ timeout: 10_000 });

      const aliceMessage = `z13 lobby from ${alice.nick} ${Date.now()}`;
      const bobMessage = `z13 lobby from ${bob.nick} ${Date.now()}`;
      await aliceLobby.sendLobbyMessage(aliceMessage);
      await bobLobby.expectLobbyMessage(aliceMessage);
      await bobLobby.sendLobbyMessage(bobMessage);
      await aliceLobby.expectLobbyMessage(bobMessage);

      await aliceLobby.videoCallButton.click();
      await bobLobby.declineAction('video_call');
      await expect(
        aliceLobby.page.getByText('Video call request declined.'),
      ).toBeVisible({ timeout: 10_000 });
      await expect(
        bobLobby.page.getByText('Video call request declined.'),
      ).toBeVisible({ timeout: 10_000 });
      await expect(aliceLobby.videoCallButton).toBeVisible();
      await expect(bobLobby.sendFileButton).toBeVisible();

      await bobLobby.sendFileButton.click();
      await aliceLobby.acceptAction('file_transfer');
      await aliceLobby.expectFileTransferReady();
      await bobLobby.expectFileTransferReady();

      const fileName = `z13-reverse-${Date.now()}.txt`;
      await bobLobby.fileInput.setInputFiles({
        name: fileName,
        mimeType: 'text/plain',
        buffer: Buffer.from(`reverse file from ${bob.nick} to ${alice.nick}`),
      });

      await expect(bobLobby.fileTransfer).toContainText(fileName, {
        timeout: 10_000,
      });
      await expect(aliceLobby.fileTransfer).toContainText(fileName, {
        timeout: 10_000,
      });
      await expect(aliceLobby.fileTransferAcceptButton).toBeVisible({
        timeout: 10_000,
      });

      const downloadPromise = aliceLobby.page.waitForEvent('download', {
        timeout: 20_000,
      });
      const aliceClosed = aliceLobby.page.waitForEvent('close', {
        timeout: 20_000,
      });
      const bobClosed = bobLobby.page.waitForEvent('close', {
        timeout: 20_000,
      });

      await aliceLobby.fileTransferAcceptButton.click();

      const download = await downloadPromise;
      expect(download.suggestedFilename()).toBe(fileName);
      await aliceClosed;
      await bobClosed;

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
      await closeP2PUsers([alice, bob]);
    }
  });

  test('audio call can decline then accept video upgrade with media tracks and peer indicators (Z14)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, 'z14a', { media: true });
    const bob = await newP2PUser(browser, 'z14b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'audio_call'));

      await bobLobby.acceptAction('audio_call');
      await aliceLobby.expectAudioCallActive();
      await bobLobby.expectAudioCallActive();
      await aliceLobby.expectRemoteAudioTrack();
      await bobLobby.expectRemoteAudioTrack();

      await aliceLobby.audioUpgradeButton.click();
      await expect(
        bobLobby.mediaCall.getByText(`${alice.nick} wants to add video`),
      ).toBeVisible({ timeout: 10_000 });
      await bobLobby.mediaCall.getByRole('button', { name: 'Decline' }).click();

      await expect(
        aliceLobby.page.getByText('Video request declined.'),
      ).toBeVisible({ timeout: 10_000 });
      await expect(
        bobLobby.page.getByText('Video request declined.'),
      ).toBeVisible({ timeout: 10_000 });
      await expect(aliceLobby.audioUpgradeButton).toBeVisible();
      await expect(bobLobby.audioUpgradeButton).toBeVisible();

      await aliceLobby.audioUpgradeButton.click();
      await expect(
        bobLobby.mediaCall.getByText(`${alice.nick} wants to add video`),
      ).toBeVisible({ timeout: 10_000 });
      await bobLobby.mediaCall.getByRole('button', { name: 'Accept' }).click();

      await aliceLobby.expectVideoCallActive();
      await bobLobby.expectVideoCallActive();
      await aliceLobby.expectLocalVideoStreamTracks();
      await bobLobby.expectLocalVideoStreamTracks();
      await aliceLobby.expectRemoteAudioTrack();
      await bobLobby.expectRemoteAudioTrack();
      await aliceLobby.expectRemoteVideoTrack();
      await bobLobby.expectRemoteVideoTrack();

      await bobLobby.muteButton.click();
      await expect(bobLobby.muteButton).toHaveAttribute('title', 'Unmute');
      await expect(aliceLobby.peerMutedIndicator).toBeVisible({
        timeout: 10_000,
      });

      await bobLobby.cameraButton.click();
      await expect(bobLobby.cameraButton).toHaveAttribute('title', 'Camera On');
      await expect(aliceLobby.peerCameraOffIndicator).toBeVisible({
        timeout: 10_000,
      });

      await aliceLobby.layoutSideBySideButton.click();
      await expect(aliceLobby.mediaCall).toHaveClass(
        /p2p-media-call--side_by_side/,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('game lobby can decline a selection, retry, and still start shared play (Z15)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, 'z15a');
    const bob = await newP2PUser(browser, 'z15b');
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ hostGame: aliceGame, peerGame: bobGame } =
        await openGameSessionsFromCommand(alice, bob));

      await expect(bobGame.lobby).toContainText(
        `Waiting for ${alice.nick} to choose a game`,
        { timeout: 10_000 },
      );

      await aliceGame.selectGame('hex_pong');
      await expect(aliceGame.lobby).toContainText(
        `Waiting for ${bob.nick} to accept Hex Pong`,
        { timeout: 10_000 },
      );
      await bobGame.declineGame('Hex Pong');

      await expect(aliceGame.gameButton('hex_pong')).toBeVisible({
        timeout: 10_000,
      });
      await expect(bobGame.lobby).toContainText(
        `Waiting for ${alice.nick} to choose a game`,
        { timeout: 10_000 },
      );

      await aliceGame.selectGame('hex_pong');
      await bobGame.acceptGame('Hex Pong');

      await aliceGame.expectGameCanvas('hex_pong');
      await bobGame.expectGameCanvas('hex_pong');
      await bobGame.expectCanvasPainted();

      const peerFrame = await bobGame.canvasFrameSignature();
      await bobGame.expectCanvasFrameChanged(peerFrame);
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('pending action blocks competing requests and requester self-accept (Z16)', async ({
    browser,
  }) => {
    test.setTimeout(70_000);

    const alice = await newP2PUser(browser, 'z16a');
    const bob = await newP2PUser(browser, 'z16b');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'generic'));

      await aliceLobby.audioCallButton.click();
      await expect(aliceLobby.actionRequest('audio_call')).toBeVisible({
        timeout: 10_000,
      });
      await expect(bobLobby.actionRequest('audio_call')).toBeVisible({
        timeout: 10_000,
      });

      await aliceLobby.videoCallButton.click();
      await expect(aliceLobby.actionRequest('audio_call')).toBeVisible();
      await expect(bobLobby.actionRequest('audio_call')).toBeVisible();
      await expect(aliceLobby.actionRequest('video_call')).toHaveCount(0);
      await expect(bobLobby.actionRequest('video_call')).toHaveCount(0);

      await aliceLobby.acceptActionButton.click();
      await expect(aliceLobby.actionRequest('audio_call')).toBeVisible();
      await expect(bobLobby.actionRequest('audio_call')).toBeVisible();
      await expect(aliceLobby.mediaCall).toHaveCount(0);
      await expect(bobLobby.mediaCall).toHaveCount(0);

      await bobLobby.declineAction('audio_call');
      await expect(
        aliceLobby.page.getByText('Audio call request declined.'),
      ).toBeVisible({ timeout: 10_000 });
      await expect(
        bobLobby.page.getByText('Audio call request declined.'),
      ).toBeVisible({ timeout: 10_000 });
      await expect(aliceLobby.audioCallButton).toBeVisible();
      await expect(bobLobby.videoCallButton).toBeVisible();
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('cancelled incoming file offer can be retried in a new clean session (Z17)', async ({
    browser,
  }) => {
    test.setTimeout(110_000);

    const alice = await newP2PUser(browser, 'z17a', {
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, 'z17b', { acceptDownloads: true });
    let firstAliceLobby: P2PLobbyPage | undefined;
    let firstBobLobby: P2PLobbyPage | undefined;
    let secondAliceLobby: P2PLobbyPage | undefined;
    let secondBobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: firstAliceLobby, receiverLobby: firstBobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'file_transfer'));

      await firstBobLobby.acceptAction('file_transfer');
      await firstAliceLobby.expectFileTransferReady();
      await firstBobLobby.expectFileTransferReady();

      const cancelledFile = `z17-cancelled-${Date.now()}.txt`;
      await firstAliceLobby.fileInput.setInputFiles({
        name: cancelledFile,
        mimeType: 'text/plain',
        buffer: Buffer.from(`first offer from ${alice.nick}`),
      });

      await expect(firstBobLobby.fileTransfer).toContainText(cancelledFile, {
        timeout: 10_000,
      });
      await expect(firstBobLobby.fileTransferAcceptButton).toBeVisible({
        timeout: 10_000,
      });
      await firstBobLobby.fileTransferCancelButton.click();

      await firstAliceLobby.expectFileCancelled(cancelledFile);
      await firstBobLobby.expectFileCancelled(cancelledFile);

      await firstAliceLobby.page.close().catch(() => {});
      await firstBobLobby.page.close().catch(() => {});
      firstAliceLobby = undefined;
      firstBobLobby = undefined;

      ({ initiatorLobby: secondAliceLobby, receiverLobby: secondBobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'file_transfer'));

      await secondBobLobby.acceptAction('file_transfer');
      await secondAliceLobby.expectFileTransferReady();
      await secondBobLobby.expectFileTransferReady();

      const completedFile = `z17-retry-${Date.now()}.txt`;
      await completeTextFileTransfer(
        secondAliceLobby,
        secondBobLobby,
        completedFile,
        `retry transfer from ${alice.nick} to ${bob.nick}`,
      );
    } finally {
      await firstAliceLobby?.page.close().catch(() => {});
      await firstBobLobby?.page.close().catch(() => {});
      await secondAliceLobby?.page.close().catch(() => {});
      await secondBobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('chat-message nick context menu starts send-file invite and consent path (Z18)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const channel = uniqueChannel('z18ctx');
    const alice = await newP2PUser(browser, 'z18a');
    const bob = await newP2PUser(browser, 'z18b');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      await joinSharedChannel(alice, bob, channel);

      await bob.chat.switchToTab(channel);
      const bobMessage = `z18 context source ${Date.now()}`;
      await bob.chat.sendMessage(bobMessage);

      await alice.chat.switchToTab(channel);
      await alice.chat.expectMessageVisible(bobMessage);
      await alice.chat.openChatNickContextMenu(bobMessage, bob.nick);
      await expect(alice.chat.chatContextCallMenuItem).toBeVisible();
      await expect(alice.chat.chatContextVideoCallMenuItem).toBeVisible();
      await expect(alice.chat.chatContextSendFileMenuItem).toBeVisible();
      await expect(alice.chat.chatContextGameMenuItem).toBeVisible();

      await alice.chat.chatContextSendFileMenuItem.click();
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );
      await alice.chat.expectMessageVisible('File transfer started');

      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromInviteCards(
          alice,
          bob,
          /^\/p2p\/[A-Za-z0-9_-]+$/,
        ));

      await bobLobby.declineAction('file_transfer');
      await expect(
        aliceLobby.page.getByText('File transfer request declined.'),
      ).toBeVisible({ timeout: 10_000 });
      await expect(aliceLobby.sendFileButton).toBeVisible();
      await expect(bobLobby.audioCallButton).toBeVisible();
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('lobby messages and file names render unsafe markup as inert text (Z19)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, 'z19a', {
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, 'z19b', { acceptDownloads: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'generic'));

      const unsafeMessage =
        '<img src=x onerror="window.__p2pLobbyXss=1"> lobby text';
      await aliceLobby.sendLobbyMessage(unsafeMessage);
      await bobLobby.expectLobbyMessage(unsafeMessage);
      await expect(bobLobby.root.locator('img[src="x"]')).toHaveCount(0);
      await expectWindowFlagUnset(bobLobby, '__p2pLobbyXss');

      await bobLobby.sendFileButton.click();
      await aliceLobby.acceptAction('file_transfer');
      await aliceLobby.expectFileTransferReady();
      await bobLobby.expectFileTransferReady();

      const unsafeFileName =
        'z19-<img src=x onerror=window.__p2pFileXss=1>.txt';
      await bobLobby.fileInput.setInputFiles({
        name: unsafeFileName,
        mimeType: 'text/plain',
        buffer: Buffer.from('unsafe filename should stay text'),
      });

      await expect(aliceLobby.fileTransfer).toContainText(unsafeFileName, {
        timeout: 10_000,
      });
      await expect(bobLobby.fileTransfer).toContainText(unsafeFileName, {
        timeout: 10_000,
      });
      await expect(aliceLobby.fileTransfer.locator('img[src="x"]')).toHaveCount(
        0,
      );
      await expect(bobLobby.fileTransfer.locator('img[src="x"]')).toHaveCount(
        0,
      );
      await expectWindowFlagUnset(aliceLobby, '__p2pFileXss');
      await expectWindowFlagUnset(bobLobby, '__p2pFileXss');

      await aliceLobby.fileTransferCancelButton.click();
      await aliceLobby.expectFileCancelled(unsafeFileName);
      await bobLobby.expectFileCancelled(unsafeFileName);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('ignoring invites closes an already open P2P lobby between users (Z20)', async ({
    browser,
  }) => {
    test.setTimeout(80_000);

    const alice = await newP2PUser(browser, 'z20a');
    const bob = await newP2PUser(browser, 'z20b');
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'generic'));

      await bob.chat.sendMessage(`/ignore ${alice.nick} invites`);
      await bob.chat.expectMessageVisible(
        `* ${alice.nick} is now ignored (invites)`,
      );

      await expect(aliceLobby.sessionEnded).toBeVisible({ timeout: 10_000 });
      await expect(bobLobby.sessionEnded).toBeVisible({ timeout: 10_000 });
      await expect(aliceLobby.sessionEnded).toContainText(
        'Session closed because a user was ignored.',
      );
      await expect(bobLobby.sessionEnded).toContainText(
        'Session closed because a user was ignored.',
      );

      await alice.chat.switchToStatusTab();
      await alice.chat.expectStatusMessageVisible(
        `P2P session with ${bob.nick} ended`,
        10_000,
      );
      await bob.chat.switchToStatusTab();
      await bob.chat.expectStatusMessageVisible(
        `P2P session with ${alice.nick} ended`,
        10_000,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });
});
