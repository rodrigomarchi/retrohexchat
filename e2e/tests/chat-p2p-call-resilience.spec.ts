import { expect, test } from '@playwright/test';
import {
  closeP2PUsers,
  newP2PUser,
  openP2PLobbiesFromCommand,
  P2PTestUser,
} from '../helpers/p2pFlows';
import { P2PLobbyPage } from '../pages/P2PLobbyPage';

async function startAudioCall(alice: P2PTestUser, bob: P2PTestUser) {
  const { initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
    await openP2PLobbiesFromCommand(alice, bob, 'audio_call');

  await bobLobby.acceptAction('audio_call');
  await aliceLobby.expectAudioCallActive();
  await bobLobby.expectAudioCallActive();
  await aliceLobby.expectRemoteAudioTrack();
  await bobLobby.expectRemoteAudioTrack();

  return { aliceLobby, bobLobby };
}

async function startVideoCall(alice: P2PTestUser, bob: P2PTestUser) {
  const { initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
    await openP2PLobbiesFromCommand(alice, bob, 'generic');

  await aliceLobby.videoCallButton.click();
  await bobLobby.acceptAction('video_call');
  await aliceLobby.expectVideoCallActive();
  await bobLobby.expectVideoCallActive();
  await aliceLobby.expectLocalVideoStreamTracks();
  await bobLobby.expectLocalVideoStreamTracks();
  await aliceLobby.expectRemoteAudioTrack();
  await bobLobby.expectRemoteAudioTrack();
  await aliceLobby.expectRemoteVideoTrack();
  await bobLobby.expectRemoteVideoTrack();

  return { aliceLobby, bobLobby };
}

test.describe('P2P call resilience and race handling', () => {
  test('offline/online during an active audio call restores coherent media controls (Z26)', async ({
    browser,
  }) => {
    test.setTimeout(100_000);

    const alice = await newP2PUser(browser, 'z26a', { media: true });
    const bob = await newP2PUser(browser, 'z26b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startAudioCall(alice, bob));

      await bob.ctx.setOffline(true);
      await bobLobby.waitUntilBrowserOffline();
      await expect(aliceLobby.sessionEnded).toHaveCount(0);

      await bob.ctx.setOffline(false);
      await bobLobby.waitUntilBrowserOnline();
      await bobLobby.waitUntilLiveViewConnected();
      await bobLobby.waitUntilOpen();

      await expect(aliceLobby.sessionEnded).toHaveCount(0);
      await expect(bobLobby.sessionEnded).toHaveCount(0);
      await aliceLobby.expectAudioCallActive();
      await bobLobby.expectAudioCallActive();

      await bobLobby.muteButton.click();
      await expect(bobLobby.muteButton).toHaveAttribute('title', 'Unmute');
      await expect(aliceLobby.peerMutedIndicator).toBeVisible({
        timeout: 10_000,
      });
    } finally {
      await bob.ctx.setOffline(false).catch(() => {});
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('offline/online during an active video call restores video tracks and controls (Z27)', async ({
    browser,
  }) => {
    test.setTimeout(110_000);

    const alice = await newP2PUser(browser, 'z27a', { media: true });
    const bob = await newP2PUser(browser, 'z27b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startVideoCall(alice, bob));

      await bob.ctx.setOffline(true);
      await bobLobby.waitUntilBrowserOffline();
      await expect(aliceLobby.sessionEnded).toHaveCount(0);

      await bob.ctx.setOffline(false);
      await bobLobby.waitUntilBrowserOnline();
      await bobLobby.waitUntilLiveViewConnected();
      await bobLobby.waitUntilOpen();

      await expect(aliceLobby.sessionEnded).toHaveCount(0);
      await expect(bobLobby.sessionEnded).toHaveCount(0);
      await aliceLobby.expectVideoCallActive();
      await bobLobby.expectVideoCallActive();
      await bobLobby.expectLocalVideoStreamTracks();
      await aliceLobby.expectRemoteVideoTrack();

      await bobLobby.cameraButton.click();
      await expect(bobLobby.cameraButton).toHaveAttribute('title', 'Camera On');
      await expect(aliceLobby.peerCameraOffIndicator).toBeVisible({
        timeout: 10_000,
      });
    } finally {
      await bob.ctx.setOffline(false).catch(() => {});
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('closing peer popup while video upgrade is pending ends the requester coherently (Z28)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, 'z28a', { media: true });
    const bob = await newP2PUser(browser, 'z28b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startAudioCall(alice, bob));

      await aliceLobby.audioUpgradeButton.click();
      await expect(
        bobLobby.mediaCall.getByText(`${alice.nick} wants to add video`),
      ).toBeVisible({ timeout: 10_000 });

      await bobLobby.page.close();
      bobLobby = undefined;

      await expect(aliceLobby.sessionEnded).toBeVisible({ timeout: 15_000 });
      await expect(aliceLobby.sessionEnded).toContainText(
        'Session closed (disconnected).',
      );
      await alice.chat.switchToStatusTab();
      await alice.chat.expectStatusMessageVisible(
        `Audio call with ${bob.nick} ended`,
        10_000,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('ignoring invites during an active video call closes both peers and clears media (Z29)', async ({
    browser,
  }) => {
    test.setTimeout(100_000);

    const alice = await newP2PUser(browser, 'z29a', { media: true });
    const bob = await newP2PUser(browser, 'z29b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startVideoCall(alice, bob));

      await bob.chat.sendMessage(`/ignore ${alice.nick} invites`);
      await bob.chat.expectMessageVisible(
        `* ${alice.nick} is now ignored (invites)`,
      );

      await expect(aliceLobby.sessionEnded).toBeVisible({ timeout: 15_000 });
      await expect(bobLobby.sessionEnded).toBeVisible({ timeout: 15_000 });
      await expect(aliceLobby.sessionEnded).toContainText(
        'Session closed because a user was ignored.',
      );
      await expect(bobLobby.sessionEnded).toContainText(
        'Session closed because a user was ignored.',
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('same users can start a fresh audio call after ending the previous call (Z30)', async ({
    browser,
  }) => {
    test.setTimeout(120_000);

    const alice = await newP2PUser(browser, 'z30a', { media: true });
    const bob = await newP2PUser(browser, 'z30b', { media: true });
    let firstAliceLobby: P2PLobbyPage | undefined;
    let firstBobLobby: P2PLobbyPage | undefined;
    let secondAliceLobby: P2PLobbyPage | undefined;
    let secondBobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby: firstAliceLobby, bobLobby: firstBobLobby } =
        await startAudioCall(alice, bob));

      const firstAliceClosed = firstAliceLobby.page.waitForEvent('close', {
        timeout: 15_000,
      });
      await firstAliceLobby.endCallButton.click();
      await firstAliceClosed;
      firstAliceLobby = undefined;

      await expect(firstBobLobby.sessionEnded).toBeVisible({ timeout: 15_000 });
      await firstBobLobby.page.close();
      firstBobLobby = undefined;

      ({ aliceLobby: secondAliceLobby, bobLobby: secondBobLobby } =
        await startAudioCall(alice, bob));

      await secondBobLobby.muteButton.click();
      await expect(secondBobLobby.muteButton).toHaveAttribute(
        'title',
        'Unmute',
      );
      await expect(secondAliceLobby.peerMutedIndicator).toBeVisible({
        timeout: 10_000,
      });
    } finally {
      await firstAliceLobby?.page.close().catch(() => {});
      await firstBobLobby?.page.close().catch(() => {});
      await secondAliceLobby?.page.close().catch(() => {});
      await secondBobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('double-clicking video-upgrade accept settles once and reaches video call (Z31)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, 'z31a', { media: true });
    const bob = await newP2PUser(browser, 'z31b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startAudioCall(alice, bob));

      await aliceLobby.audioUpgradeButton.click();
      await expect(
        bobLobby.mediaCall.getByText(`${alice.nick} wants to add video`),
      ).toBeVisible({ timeout: 10_000 });

      await bobLobby.mediaCall
        .getByRole('button', { name: 'Accept' })
        .dblclick();

      await aliceLobby.expectVideoCallActive();
      await bobLobby.expectVideoCallActive();
      await aliceLobby.expectRemoteVideoTrack();
      await bobLobby.expectRemoteVideoTrack();
      await expect(
        bobLobby.mediaCall.getByText(`${alice.nick} wants to add video`),
      ).toHaveCount(0);
      await expect(
        aliceLobby.page.getByText('Video request declined.'),
      ).toHaveCount(0);
      await expect(
        bobLobby.page.getByText('Video request declined.'),
      ).toHaveCount(0);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });
});
