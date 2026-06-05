import { expect, test } from '@playwright/test';
import { uniqueChannel } from '../helpers/chatUsers';
import {
  closeP2PUsers,
  newP2PUser,
  openP2PLobbiesFromCommand,
  openP2PLobbiesFromInviteCards,
  P2PTestUser,
} from '../helpers/p2pFlows';
import { P2PLobbyPage } from '../pages/P2PLobbyPage';

const cameraPermissionText =
  'Camera permission denied. Enable camera permission in your browser and try again.';

async function joinSharedChannel(
  alice: P2PTestUser,
  bob: P2PTestUser,
  channel: string,
) {
  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);
  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);
}

async function startAudioCall(
  alice: P2PTestUser,
  bob: P2PTestUser,
) {
  const { initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
    await openP2PLobbiesFromCommand(alice, bob, 'audio_call');

  await bobLobby.acceptAction('audio_call');
  await aliceLobby.expectAudioCallActive();
  await bobLobby.expectAudioCallActive();
  await aliceLobby.expectRemoteAudioTrack();
  await bobLobby.expectRemoteAudioTrack();

  return { aliceLobby, bobLobby };
}

test.describe('P2P audio/video media edge cases', () => {
  test('direct video call with denied camera shows camera guidance and leaves lobby usable (Z21)', async ({
    browser,
  }) => {
    test.setTimeout(80_000);

    const alice = await newP2PUser(browser, 'z21a', {
      media: 'camera-denied',
    });
    const bob = await newP2PUser(browser, 'z21b', {
      media: 'camera-denied',
    });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'generic'));

      await aliceLobby.videoCallButton.click();
      await bobLobby.acceptAction('video_call');

      await expect(aliceLobby.page.getByText(cameraPermissionText)).toHaveCount(
        1,
        { timeout: 10_000 },
      );
      await expect(bobLobby.page.getByText(cameraPermissionText)).toHaveCount(
        1,
        { timeout: 10_000 },
      );
      await expect(aliceLobby.mediaCall).toHaveCount(0);
      await expect(bobLobby.mediaCall).toHaveCount(0);
      await expect(aliceLobby.closeSessionButton).toBeVisible();
      await expect(bobLobby.closeSessionButton).toBeVisible();

      const lobbyMessage = `z21 usable after denied camera ${Date.now()}`;
      await aliceLobby.sendLobbyMessage(lobbyMessage);
      await bobLobby.expectLobbyMessage(lobbyMessage);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('camera denial during audio-to-video upgrade keeps both peers in audio call (Z22)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, 'z22a', { media: true });
    const bob = await newP2PUser(browser, 'z22b', {
      media: 'camera-denied',
    });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startAudioCall(alice, bob));

      await aliceLobby.audioUpgradeButton.click();
      await expect(
        bobLobby.mediaCall.getByText(`${alice.nick} wants to add video`),
      ).toBeVisible({ timeout: 10_000 });
      await bobLobby.mediaCall.getByRole('button', { name: 'Accept' }).click();

      await expect(bobLobby.page.getByText(cameraPermissionText)).toBeVisible({
        timeout: 15_000,
      });
      await expect(aliceLobby.page.getByText(cameraPermissionText)).toBeVisible({
        timeout: 15_000,
      });

      await aliceLobby.expectAudioCallActive();
      await bobLobby.expectAudioCallActive();
      await aliceLobby.expectRemoteAudioTrack();
      await bobLobby.expectRemoteAudioTrack();
      await expect(aliceLobby.localVideo).toHaveCount(0);
      await expect(bobLobby.localVideo).toHaveCount(0);
      await expect(aliceLobby.cameraButton).toHaveCount(0);
      await expect(bobLobby.cameraButton).toHaveCount(0);
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('ending an active audio call closes local popup and ends peer session (Z23)', async ({
    browser,
  }) => {
    test.setTimeout(80_000);

    const alice = await newP2PUser(browser, 'z23a', { media: true });
    const bob = await newP2PUser(browser, 'z23b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startAudioCall(alice, bob));

      const aliceClosed = aliceLobby.page.waitForEvent('close', {
        timeout: 15_000,
      });
      await aliceLobby.endCallButton.click();
      await aliceClosed;
      aliceLobby = undefined;

      await expect(bobLobby.sessionEnded).toBeVisible({ timeout: 15_000 });
      await expect(bobLobby.sessionEnded).toContainText('Call ended.');
      await bob.chat.switchToStatusTab();
      await bob.chat.expectStatusMessageVisible(
        `Audio call with ${alice.nick} ended`,
        10_000,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('closing a popup during an active audio call disconnects the peer coherently (Z24)', async ({
    browser,
  }) => {
    test.setTimeout(80_000);

    const alice = await newP2PUser(browser, 'z24a', { media: true });
    const bob = await newP2PUser(browser, 'z24b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ aliceLobby, bobLobby } = await startAudioCall(alice, bob));

      await aliceLobby.page.close();
      aliceLobby = undefined;

      await expect(bobLobby.sessionEnded).toBeVisible({ timeout: 15_000 });
      await expect(bobLobby.sessionEnded).toContainText(
        'Session closed (disconnected).',
      );
      await bob.chat.switchToStatusTab();
      await bob.chat.expectStatusMessageVisible(
        `Audio call with ${alice.nick} ended`,
        10_000,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('nicklist video-call action starts full video media with tracks (Z25)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const channel = uniqueChannel('z25vid');
    const alice = await newP2PUser(browser, 'z25a', { media: true });
    const bob = await newP2PUser(browser, 'z25b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      await joinSharedChannel(alice, bob, channel);

      await alice.chat.switchToTab(channel);
      await alice.chat.expectNickInList(bob.nick);
      await alice.chat.openNicklistContextMenu(bob.nick);
      await expect(alice.chat.nicklistContextVideoCallMenuItem).toBeVisible();
      await alice.chat.nicklistContextVideoCallMenuItem.click();

      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );
      await alice.chat.expectMessageVisible('Video call started');

      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromInviteCards(
          alice,
          bob,
          /^\/p2p\/[A-Za-z0-9_-]+$/,
        ));

      await bobLobby.acceptAction('video_call');
      await aliceLobby.expectVideoCallActive();
      await bobLobby.expectVideoCallActive();
      await aliceLobby.expectLocalVideoStreamTracks();
      await bobLobby.expectLocalVideoStreamTracks();
      await aliceLobby.expectRemoteAudioTrack();
      await bobLobby.expectRemoteAudioTrack();
      await aliceLobby.expectRemoteVideoTrack();
      await bobLobby.expectRemoteVideoTrack();
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });
});
