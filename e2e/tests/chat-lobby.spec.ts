import { test, expect } from '@playwright/test';
import { newP2PUser, closeP2PUsers } from '../helpers/p2pFlows';
import {
  openLobbiesFromCommand,
  openLobbiesFromContextMenu,
} from '../helpers/lobbyFlows';

test.describe('Universal lobby', () => {
  test('/lobby command opens a connected lobby for both peers', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );

      await expect(initiatorLobby.dock).toBeVisible();
      await expect(receiverLobby.dock).toBeVisible();

      // The dock enables only once the persistent WebRTC link is established.
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('runs a video call, a game, and chat all at the same time', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );

      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      // 1) Each peer turns on their own camera (self-controlled media).
      await initiatorLobby.startVideoCall();
      await receiverLobby.startVideoCall();
      await expect(initiatorLobby.remoteVideo).toBeVisible();
      await expect(receiverLobby.remoteVideo).toBeVisible();

      // 2) Start a game WHILE the call is running.
      await initiatorLobby.proposeGame('Hex Pong');
      await receiverLobby.acceptGame();
      await expect(initiatorLobby.gameCanvas).toBeVisible();
      await expect(receiverLobby.gameCanvas).toBeVisible();

      // 3) Chat at the same time.
      await initiatorLobby.sendChat('all at once');
      await receiverLobby.expectChatMessage('all at once');

      // The thesis: media + game + chat coexist on one connection.
      await expect(initiatorLobby.mediaPanel).toBeVisible();
      await expect(initiatorLobby.remoteVideo).toBeVisible();
      await expect(initiatorLobby.gameCanvas).toBeVisible();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('ending a game keeps the lobby connected for more features', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );

      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.proposeGame('Hex Pong');
      await receiverLobby.acceptGame();
      await expect(initiatorLobby.gameCanvas).toBeVisible();

      // End the game — the connection must stay alive.
      await initiatorLobby.gamePanel
        .getByRole('button', { name: 'End game' })
        .click();

      await expect(initiatorLobby.ended).toHaveCount(0);
      await expect(initiatorLobby.audioButton).toBeEnabled();
      await expect(initiatorLobby.videoButton).toBeEnabled();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('an audio call can be upgraded to video in place', async ({ browser }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      // Both peers go audio-only first (each controls their own media, so both
      // need an active call for the media panels — and remote video — to render).
      await initiatorLobby.startAudioCall();
      await receiverLobby.startAudioCall();
      await expect(initiatorLobby.mediaPanel).toBeVisible();
      await expect(initiatorLobby.addVideoButton).toBeVisible();

      // Upgrade alice audio→video without tearing the call down; the new track
      // reaches bob over the same renegotiated connection.
      await initiatorLobby.addVideoButton.click();
      await expect(initiatorLobby.localVideo).toBeVisible();
      await expect(receiverLobby.remoteVideo).toBeVisible({ timeout: 15_000 });
      await initiatorLobby.expectStillConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('sends a file during a video call without dropping the call', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', {
      media: true,
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, 'lobb', {
      media: true,
      acceptDownloads: true,
    });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      // Bring up a call, then transfer a file over the SAME connection.
      await initiatorLobby.startVideoCall();
      await receiverLobby.startVideoCall();

      await initiatorLobby.openFilePanel();
      const fileName = 'lobby-during-call.txt';
      await initiatorLobby.sendFile(fileName, 'concurrent call + file payload');

      // The receiver's panel auto-opens and offers the file.
      await expect(receiverLobby.filePanel).toBeVisible({ timeout: 15_000 });
      await expect(receiverLobby.fileTransfer).toContainText(fileName, {
        timeout: 15_000,
      });
      await expect(receiverLobby.fileTransferAccept).toBeVisible({
        timeout: 15_000,
      });

      const downloadPromise = receiverLobby.page.waitForEvent('download', {
        timeout: 20_000,
      });
      await receiverLobby.fileTransferAccept.click();
      const download = await downloadPromise;
      expect(download.suggestedFilename()).toBe(fileName);

      // The call and the connection survive the completed transfer.
      await expect(initiatorLobby.remoteVideo).toBeVisible();
      await initiatorLobby.expectStillConnected();
      await receiverLobby.expectStillConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('transfers a file while a game is running', async ({ browser }) => {
    const alice = await newP2PUser(browser, 'loba', {
      media: true,
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, 'lobb', {
      media: true,
      acceptDownloads: true,
    });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      // Start a game first (uses the "gamedata" channel)...
      await initiatorLobby.proposeGame('Hex Pong');
      await receiverLobby.acceptGame();
      await expect(initiatorLobby.gameCanvas).toBeVisible();

      // ...then send a file over the independent "filetransfer" channel.
      await initiatorLobby.openFilePanel();
      const fileName = 'lobby-during-game.txt';
      await initiatorLobby.sendFile(fileName, 'file payload alongside a game');

      await expect(receiverLobby.fileTransferAccept).toBeVisible({
        timeout: 15_000,
      });
      const downloadPromise = receiverLobby.page.waitForEvent('download', {
        timeout: 20_000,
      });
      await receiverLobby.fileTransferAccept.click();
      const download = await downloadPromise;
      expect(download.suggestedFilename()).toBe(fileName);

      // The game keeps running on its own data channel.
      await expect(initiatorLobby.gameCanvas).toBeVisible();
      await initiatorLobby.expectStillConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('declining a game proposal keeps the lobby connected', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.proposeGame('Hex Pong');
      await receiverLobby.declineGame();

      // No game canvas appears and both peers stay connected for other features.
      await expect(initiatorLobby.gameCanvas).toHaveCount(0);
      await initiatorLobby.expectStillConnected();
      await receiverLobby.expectStillConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('media controls mute, toggle camera, and end the call back to the dock', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.startVideoCall();
      await receiverLobby.startVideoCall();

      // Mute → the peer sees the muted indicator; unmute clears it. The compact
      // media buttons are icon-only, so the label lives on the `title` attribute.
      await initiatorLobby.muteButton.click();
      await expect(initiatorLobby.muteButton).toHaveAttribute('title', 'Unmute');
      await expect(receiverLobby.peerMutedIndicator).toBeVisible({
        timeout: 10_000,
      });
      await initiatorLobby.muteButton.click();
      await expect(initiatorLobby.muteButton).toHaveAttribute('title', 'Mute');

      // Camera off → the peer sees the camera-off placeholder.
      await initiatorLobby.cameraButton.click();
      await expect(initiatorLobby.cameraButton).toHaveAttribute(
        'title',
        'Camera On',
      );
      await expect(receiverLobby.peerCameraOffIndicator).toBeVisible({
        timeout: 10_000,
      });

      // End the call → the dock re-enables for a fresh activity.
      await initiatorLobby.endCallButton.click();
      await expect(initiatorLobby.localVideo).toHaveCount(0);
      await initiatorLobby.expectStillConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('leaving the lobby ends it for both peers', async ({ browser }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.leaveButtonHeader.click();

      // The peer is told the lobby ended.
      await expect(receiverLobby.ended).toBeVisible({ timeout: 15_000 });
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('opens a connected lobby from the nicklist context menu', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });
    const channel = `#lob${Math.random().toString(36).slice(2, 8)}`;

    try {
      // Both users must share a channel so the nick appears in the nicklist.
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await alice.chat.expectNickInList(bob.nick);

      const { initiatorLobby, receiverLobby } = await openLobbiesFromContextMenu(
        alice,
        bob,
      );

      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('delivers video both ways when both peers enable it at once', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      // Both turn on video at the same instant → renegotiation glare. With the
      // single-offerer model, neither side ends up with a muted (frozen) remote.
      await Promise.all([
        initiatorLobby.videoButton.click(),
        receiverLobby.videoButton.click(),
      ]);

      await initiatorLobby.expectRemoteVideoFlowing();
      await receiverLobby.expectRemoteVideoFlowing();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('runs video, file, game, and chat all on one connection', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', {
      media: true,
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, 'lobb', {
      media: true,
      acceptDownloads: true,
    });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      // 1) Video call on both peers.
      await initiatorLobby.startVideoCall();
      await receiverLobby.startVideoCall();

      // 2) A game over the gamedata channel, concurrently.
      await initiatorLobby.proposeGame('Hex Pong');
      await receiverLobby.acceptGame();
      await expect(initiatorLobby.gameCanvas).toBeVisible();

      // 3) A file over the filetransfer channel, concurrently.
      await initiatorLobby.openFilePanel();
      const fileName = 'all-at-once.txt';
      await initiatorLobby.sendFile(fileName, 'video + game + file + chat');
      await expect(receiverLobby.fileTransferAccept).toBeVisible({
        timeout: 15_000,
      });
      const downloadPromise = receiverLobby.page.waitForEvent('download', {
        timeout: 20_000,
      });
      await receiverLobby.fileTransferAccept.click();
      const download = await downloadPromise;
      expect(download.suggestedFilename()).toBe(fileName);

      // 4) Chat, still concurrent.
      await initiatorLobby.sendChat('everything together');
      await receiverLobby.expectChatMessage('everything together');

      // All four modalities coexist on the single persistent connection.
      await expect(initiatorLobby.remoteVideo).toBeVisible();
      await expect(initiatorLobby.gameCanvas).toBeVisible();
      await initiatorLobby.expectStillConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('shows live network telemetry during a call', async ({ browser }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.startVideoCall();
      await receiverLobby.startVideoCall();

      // The factory polls getStats every ~3s; the panel renders once stats land.
      await expect(initiatorLobby.networkPanel).toBeVisible({ timeout: 15_000 });
      await expect(initiatorLobby.networkHealth).not.toBeEmpty();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('switches video call layouts', async ({ browser }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.startVideoCall();
      await receiverLobby.startVideoCall();

      // Default focus layout, then switch through the others.
      await expect(initiatorLobby.mediaContainer).toHaveClass(
        /lobby-media--focus/,
      );
      await initiatorLobby.setLayout('Side by side');
      await expect(initiatorLobby.mediaContainer).toHaveClass(
        /lobby-media--side_by_side/,
      );
      await initiatorLobby.setLayout('Maximize');
      await expect(initiatorLobby.mediaContainer).toHaveClass(
        /lobby-media--maximized/,
      );
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('lists media devices on demand during a call', async ({ browser }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.startVideoCall();
      await initiatorLobby.devicesButton.click();

      await expect(initiatorLobby.devicesPanel).toBeVisible({ timeout: 10_000 });
      await expect(
        initiatorLobby.devicesPanel.locator('select'),
      ).not.toHaveCount(0);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('rejects a blocked file extension with a validation error', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'loba', { media: true });
    const bob = await newP2PUser(browser, 'lobb', { media: true });

    try {
      const { initiatorLobby, receiverLobby } = await openLobbiesFromCommand(
        alice,
        bob,
      );
      await initiatorLobby.waitUntilConnected();
      await receiverLobby.waitUntilConnected();

      await initiatorLobby.openFilePanel();
      // `.exe` is in the lobby's blocked-extensions list.
      await initiatorLobby.sendFile('danger.exe', 'should be rejected');

      await expect(initiatorLobby.fileValidationError).toBeVisible({
        timeout: 10_000,
      });
      // No offer reaches the peer for a rejected file.
      await expect(receiverLobby.fileTransferAccept).toHaveCount(0);
      await initiatorLobby.expectStillConnected();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });
});
