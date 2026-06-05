import { expect, test } from '@playwright/test';
import {
  closeP2PUsers,
  newP2PUser,
  openGameSessionsFromCommand,
  P2PTestUser,
} from '../helpers/p2pFlows';
import { GameSessionPage } from '../pages/GameSessionPage';

const cameraPermissionText =
  'Camera permission denied. Enable camera permission in your browser and try again.';

async function openStartedGame(host: P2PTestUser, peer: P2PTestUser) {
  const { hostGame, peerGame } = await openGameSessionsFromCommand(host, peer);

  await hostGame.selectGame('hex_pong');
  await peerGame.acceptGame('Hex Pong');
  await hostGame.expectGameCanvas('hex_pong');
  await peerGame.expectGameCanvas('hex_pong');
  await hostGame.expectCanvasPainted();
  await peerGame.expectCanvasPainted();

  return { hostGame, peerGame };
}

async function startGameVideoCall(hostGame: GameSessionPage, peerGame: GameSessionPage) {
  await hostGame.startVideoButton.click();
  await hostGame.expectVideoCallActive();
  await hostGame.expectLocalVideoStreamTracks();
  await peerGame.expectIncomingVideoCall();
  await peerGame.expectRemoteVideoStreamTrack();
  await peerGame.expectRemoteAudioTrack();
}

test.describe('P2P game media edge cases', () => {
  test('active game voice call can upgrade to video and deliver tracks (Z36)', async ({
    browser,
  }) => {
    test.setTimeout(100_000);

    const alice = await newP2PUser(browser, 'z36a', { media: true });
    const bob = await newP2PUser(browser, 'z36b', { media: true });
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ hostGame: aliceGame, peerGame: bobGame } = await openStartedGame(
        alice,
        bob,
      ));

      await aliceGame.startVoiceButton.click();
      await aliceGame.expectAudioCallActive();
      await expect(bobGame.joinMediaButton).toBeVisible({ timeout: 10_000 });

      await aliceGame.audioUpgradeButton.click();

      await aliceGame.expectVideoCallActive();
      await aliceGame.expectLocalVideoStreamTracks();
      await bobGame.expectIncomingVideoCall();
      await bobGame.expectRemoteVideoStreamTrack();
      await bobGame.expectRemoteAudioTrack();
      await expect(aliceGame.canvas).toBeVisible();
      await expect(bobGame.canvas).toBeVisible();
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('camera denial inside active game media leaves canvas playable and media idle (Z37)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, 'z37a', {
      media: 'camera-denied',
    });
    const bob = await newP2PUser(browser, 'z37b', { media: true });
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ hostGame: aliceGame, peerGame: bobGame } = await openStartedGame(
        alice,
        bob,
      ));

      await aliceGame.startVideoButton.click();

      await expect(aliceGame.page.getByText(cameraPermissionText)).toBeVisible({
        timeout: 10_000,
      });
      await aliceGame.expectMediaIdle();
      await bobGame.expectMediaIdle();
      await expect(aliceGame.canvas).toBeVisible();
      await expect(bobGame.canvas).toBeVisible();

      const peerFrame = await bobGame.canvasFrameSignature();
      await bobGame.expectCanvasFrameChanged(peerFrame);
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('ending an active game while video media is running closes peer coherently (Z38)', async ({
    browser,
  }) => {
    test.setTimeout(100_000);

    const alice = await newP2PUser(browser, 'z38a', { media: true });
    const bob = await newP2PUser(browser, 'z38b', { media: true });
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ hostGame: aliceGame, peerGame: bobGame } = await openStartedGame(
        alice,
        bob,
      ));
      await startGameVideoCall(aliceGame, bobGame);

      const aliceClosed = aliceGame.page.waitForEvent('close', {
        timeout: 15_000,
      });
      await aliceGame.endGameButton.click();
      await aliceClosed;
      aliceGame = undefined;

      await expect(bobGame.sessionEnded).toBeVisible({ timeout: 15_000 });
      await expect(bobGame.sessionEnded).toContainText('Game ended.');
      await bob.chat.switchToStatusTab();
      await bob.chat.expectStatusMessageVisible(
        `with ${alice.nick} ended`,
        10_000,
      );
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('closing popup during active game video media disconnects peer coherently (Z39)', async ({
    browser,
  }) => {
    test.setTimeout(100_000);

    const alice = await newP2PUser(browser, 'z39a', { media: true });
    const bob = await newP2PUser(browser, 'z39b', { media: true });
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ hostGame: aliceGame, peerGame: bobGame } = await openStartedGame(
        alice,
        bob,
      ));
      await startGameVideoCall(aliceGame, bobGame);

      await aliceGame.page.close();
      aliceGame = undefined;

      await expect(bobGame.sessionEnded).toBeVisible({ timeout: 15_000 });
      await expect(bobGame.sessionEnded).toContainText('Peer disconnected.');
      await bob.chat.switchToStatusTab();
      await bob.chat.expectStatusMessageVisible(
        `with ${alice.nick} ended`,
        10_000,
      );
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });
});
