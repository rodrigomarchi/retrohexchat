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

async function expectLobbyStillUsable(
  senderLobby: P2PLobbyPage,
  receiverLobby: P2PLobbyPage,
  text: string,
) {
  await expect(senderLobby.mediaCall).toHaveCount(0);
  await expect(receiverLobby.mediaCall).toHaveCount(0);
  await expect(senderLobby.closeSessionButton).toBeVisible();
  await expect(receiverLobby.closeSessionButton).toBeVisible();
  await senderLobby.sendLobbyMessage(text);
  await receiverLobby.expectLobbyMessage(text);
}

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

test.describe('P2P call device error handling', () => {
  test('audio call with missing microphone shows microphone-specific guidance (Z32)', async ({
    browser,
  }) => {
    test.setTimeout(80_000);

    const alice = await newP2PUser(browser, 'z32a', {
      media: 'mic-missing',
    });
    const bob = await newP2PUser(browser, 'z32b', { media: 'mic-missing' });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'audio_call'));

      await bobLobby.acceptAction('audio_call');

      await expect(aliceLobby.page.getByText('No microphone found.')).toHaveCount(
        1,
        { timeout: 10_000 },
      );
      await expect(bobLobby.page.getByText('No microphone found.')).toHaveCount(
        1,
        { timeout: 10_000 },
      );

      await expectLobbyStillUsable(
        aliceLobby,
        bobLobby,
        `z32 usable after missing mic ${Date.now()}`,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('video call with missing camera shows missing-camera guidance (Z33)', async ({
    browser,
  }) => {
    test.setTimeout(80_000);

    const alice = await newP2PUser(browser, 'z33a', {
      media: 'camera-missing',
    });
    const bob = await newP2PUser(browser, 'z33b', {
      media: 'camera-missing',
    });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'generic'));

      await aliceLobby.videoCallButton.click();
      await bobLobby.acceptAction('video_call');

      await expect(aliceLobby.page.getByText('No camera found.')).toHaveCount(1, {
        timeout: 10_000,
      });
      await expect(bobLobby.page.getByText('No camera found.')).toHaveCount(1, {
        timeout: 10_000,
      });

      await expectLobbyStillUsable(
        aliceLobby,
        bobLobby,
        `z33 usable after missing camera ${Date.now()}`,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('video call with busy camera shows not-readable guidance (Z34)', async ({
    browser,
  }) => {
    test.setTimeout(80_000);

    const alice = await newP2PUser(browser, 'z34a', { media: 'camera-busy' });
    const bob = await newP2PUser(browser, 'z34b', { media: 'camera-busy' });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      ({ initiatorLobby: aliceLobby, receiverLobby: bobLobby } =
        await openP2PLobbiesFromCommand(alice, bob, 'generic'));

      await aliceLobby.videoCallButton.click();
      await bobLobby.acceptAction('video_call');

      const busyText =
        'Camera in use by another application. Try closing other programs using the camera.';
      await expect(aliceLobby.page.getByText(busyText)).toHaveCount(1, {
        timeout: 10_000,
      });

      await expectLobbyStillUsable(
        aliceLobby,
        bobLobby,
        `z34 usable after busy camera ${Date.now()}`,
      );
    } finally {
      await aliceLobby?.page.close().catch(() => {});
      await bobLobby?.page.close().catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test('chat-message nick context menu starts full video call with tracks (Z35)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const channel = uniqueChannel('z35ctx');
    const alice = await newP2PUser(browser, 'z35a', { media: true });
    const bob = await newP2PUser(browser, 'z35b', { media: true });
    let aliceLobby: P2PLobbyPage | undefined;
    let bobLobby: P2PLobbyPage | undefined;

    try {
      await joinSharedChannel(alice, bob, channel);

      await bob.chat.switchToTab(channel);
      const bobMessage = `z35 video context source ${Date.now()}`;
      await bob.chat.sendMessage(bobMessage);

      await alice.chat.switchToTab(channel);
      await alice.chat.expectMessageVisible(bobMessage);
      await alice.chat.openChatNickContextMenu(bobMessage, bob.nick);
      await expect(alice.chat.chatContextVideoCallMenuItem).toBeVisible();
      await alice.chat.chatContextVideoCallMenuItem.click();

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
