import { Locator, Page, expect } from '@playwright/test';

/**
 * Page object for the universal lobby (`/lobby/:token`) — one persistent
 * connection that hosts audio/video, file transfer and games concurrently.
 */
export class LobbyPage {
  readonly page: Page;
  readonly root: Locator;
  readonly dock: Locator;
  readonly audioButton: Locator;
  readonly videoButton: Locator;
  readonly fileButton: Locator;
  readonly gameButton: Locator;
  readonly leaveButton: Locator;
  readonly mediaPanel: Locator;
  readonly remoteVideo: Locator;
  readonly localVideo: Locator;
  readonly endCallButton: Locator;
  readonly networkPanel: Locator;
  readonly filePanel: Locator;
  readonly fileInput: Locator;
  readonly gamePanel: Locator;
  readonly gameConsent: Locator;
  readonly gameCanvas: Locator;
  readonly chat: Locator;
  readonly chatInput: Locator;
  readonly chatSendButton: Locator;
  readonly ended: Locator;
  readonly privacyButton: Locator;
  readonly leaveButtonHeader: Locator;
  readonly fileTransfer: Locator;
  readonly fileTransferAccept: Locator;
  readonly muteButton: Locator;
  readonly cameraButton: Locator;
  readonly addVideoButton: Locator;
  readonly peerMutedIndicator: Locator;
  readonly peerCameraOffIndicator: Locator;
  readonly networkHealth: Locator;
  readonly mediaContainer: Locator;
  readonly devicesButton: Locator;
  readonly devicesPanel: Locator;
  readonly fileValidationError: Locator;

  constructor(page: Page) {
    this.page = page;
    this.root = page.locator('.lobby');
    this.dock = page.getByTestId('lobby-dock');
    this.audioButton = page.getByTestId('lobby-dock-audio');
    this.videoButton = page.getByTestId('lobby-dock-video');
    this.fileButton = page.getByTestId('lobby-dock-file');
    this.gameButton = page.getByTestId('lobby-dock-game');
    this.leaveButton = page.getByTestId('lobby-leave');
    this.mediaPanel = page.getByTestId('lobby-media-panel');
    this.remoteVideo = page.locator('#lobby-remote-video');
    this.localVideo = page.locator('#lobby-local-video');
    this.endCallButton = page.locator('[data-lobby-media-action="end-call"]');
    this.networkPanel = page.getByTestId('lobby-network-panel');
    this.filePanel = page.getByTestId('lobby-file-panel');
    this.fileInput = page.locator('#lobby-file-input');
    this.gamePanel = page.getByTestId('lobby-game-panel');
    this.gameConsent = page.getByTestId('lobby-game-consent');
    this.gameCanvas = page.locator('#lobby-game-canvas canvas');
    this.chat = page.getByTestId('lobby-chat');
    this.chatInput = this.chat.getByPlaceholder('Type a message');
    this.chatSendButton = this.chat.getByRole('button', { name: 'Send', exact: true });
    this.ended = page.getByTestId('lobby-ended');
    this.privacyButton = page.getByTestId('lobby-privacy');
    this.leaveButtonHeader = page.getByTestId('lobby-leave');
    this.fileTransfer = this.filePanel.getByTestId('file-transfer');
    this.fileTransferAccept = this.filePanel.getByTestId('file-transfer-accept');
    this.muteButton = page.locator('[data-lobby-media-action="mute"]');
    this.cameraButton = page.locator('[data-lobby-media-action="camera"]');
    this.addVideoButton = page.locator('[data-lobby-media-action="upgrade"]');
    this.peerMutedIndicator = page.getByTestId('lobby-peer-muted');
    this.peerCameraOffIndicator = page.getByTestId('lobby-peer-camera-off');
    this.networkHealth = page.getByTestId('lobby-network-health');
    this.mediaContainer = page.locator('.lobby-media');
    this.devicesButton = page.locator('[data-lobby-media-action="device-settings"]');
    this.devicesPanel = page.getByTestId('lobby-devices');
    this.fileValidationError = page.getByTestId('lobby-ft-validation-error');
  }

  async waitUntilOpen() {
    await expect(this.page).toHaveURL(/\/lobby\/[A-Za-z0-9_-]+$/);
    await expect(this.root).toBeVisible();
  }

  async waitUntilLiveViewConnected() {
    await expect
      .poll(
        () =>
          this.page.evaluate(
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            () => !!(window as any).liveSocket?.isConnected?.(),
          ),
        { timeout: 15_000 },
      )
      .toBe(true);
  }

  /** The dock buttons enable only once the persistent WebRTC link is up. */
  async waitUntilConnected() {
    await expect(this.audioButton).toBeEnabled({ timeout: 35_000 });
  }

  async startVideoCall() {
    await this.videoButton.click();
    await expect(this.remoteVideo).toBeVisible();
  }

  async startAudioCall() {
    await this.audioButton.click();
  }

  async openGamePanel() {
    await this.gameButton.click();
    await expect(this.gamePanel).toBeVisible();
  }

  async proposeGame(name: string) {
    await this.openGamePanel();
    await this.gamePanel.getByRole('button', { name }).click();
  }

  async acceptGame() {
    await expect(this.gameConsent).toBeVisible({ timeout: 15_000 });
    await this.gameConsent.getByRole('button', { name: 'Accept' }).click();
  }

  async declineGame() {
    await expect(this.gameConsent).toBeVisible({ timeout: 15_000 });
    await this.gameConsent.getByRole('button', { name: 'Decline' }).click();
  }

  async openFilePanel() {
    await this.fileButton.click();
    await expect(this.filePanel).toBeVisible();
    await expect(this.fileInput).toBeAttached();
  }

  async sendFile(name: string, content: string) {
    await this.fileInput.setInputFiles({
      name,
      mimeType: 'text/plain',
      buffer: Buffer.from(content),
    });
  }

  async setLayout(label: string) {
    await this.mediaPanel.getByRole('button', { name: label, exact: true }).click();
  }

  /**
   * Reads the actual RTP state of the remote video element — `videoLive` is true
   * only when a remote video track exists AND is receiving packets (not muted).
   * This catches one-directional media that a visibility check would miss.
   */
  async remoteVideoLive(): Promise<boolean> {
    return this.page.evaluate(() => {
      const v = document.getElementById(
        'lobby-remote-video',
      ) as HTMLVideoElement | null;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const stream = v?.srcObject as any;
      const track = stream?.getVideoTracks?.()[0];
      return (
        !!track && track.readyState === 'live' && track.muted === false
      );
    });
  }

  async expectRemoteVideoFlowing() {
    await expect
      .poll(() => this.remoteVideoLive(), { timeout: 15_000 })
      .toBe(true);
  }

  async sendChat(text: string) {
    await this.chatInput.fill(text);
    await this.chatSendButton.click();
  }

  async expectChatMessage(text: string) {
    await expect(this.chat).toContainText(text, { timeout: 10_000 });
  }

  /**
   * The persistent connection must outlive any single feature. The file/game dock
   * buttons stay enabled whenever connected (unlike audio/video, which disable
   * during an active call), so they are the reliable "still connected" signal.
   */
  async expectStillConnected() {
    await expect(this.ended).toHaveCount(0);
    await expect(this.fileButton).toBeEnabled();
    await expect(this.gameButton).toBeEnabled();
  }
}

export async function openLobbyFromInvite(
  sourcePage: Page,
  inviteLink: Locator,
): Promise<LobbyPage> {
  const popupPromise = sourcePage.waitForEvent('popup');
  await inviteLink.click();
  const page = await popupPromise;
  const lobby = new LobbyPage(page);
  await lobby.waitUntilOpen();
  return lobby;
}
