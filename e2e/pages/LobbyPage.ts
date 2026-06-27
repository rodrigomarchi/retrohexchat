import { Locator, Page, expect } from "@playwright/test";

/**
 * Page object for the universal lobby (`/lobby/:token`) — one persistent
 * connection that hosts audio/video, file transfer and games concurrently,
 * rendered as a Win98 desktop. Features live in draggable windows; navigation is
 * the taskbar Start menu. Window chrome is owned client-side by WindowManagerHook.
 */
export class LobbyPage {
  readonly page: Page;
  readonly root: Locator;
  readonly desktop: Locator;
  /** Back-compat alias used by older assertions — the desktop is the shell now. */
  readonly dock: Locator;

  readonly startButton: Locator;
  readonly startMenu: Locator;
  readonly audioButton: Locator;
  readonly videoButton: Locator;
  readonly fileMenuItem: Locator;
  readonly gameMenuItem: Locator;
  readonly leaveButton: Locator;
  readonly privacyButton: Locator;

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
  readonly fileTransfer: Locator;
  readonly fileTransferAccept: Locator;
  readonly muteButton: Locator;
  readonly cameraButton: Locator;
  readonly addVideoButton: Locator;
  readonly enableAudioButton: Locator;
  readonly enableVideoButton: Locator;
  readonly peerMutedIndicator: Locator;
  readonly peerCameraOffIndicator: Locator;
  readonly networkHealth: Locator;
  readonly mediaContainer: Locator;
  readonly devicesButton: Locator;
  readonly devicesPanel: Locator;
  readonly fileValidationError: Locator;

  constructor(page: Page) {
    this.page = page;
    this.root = page.locator(".lobby");
    this.desktop = page.getByTestId("lobby-desktop");
    this.dock = this.desktop;

    this.startButton = page.locator("[data-window-start]");
    this.startMenu = page.locator("[data-window-start-menu]");
    this.audioButton = page.getByTestId("lobby-menu-audio");
    this.videoButton = page.getByTestId("lobby-menu-video");
    this.fileMenuItem = page.getByTestId("lobby-menu-file");
    this.gameMenuItem = page.getByTestId("lobby-menu-game");
    this.leaveButton = page.getByTestId("lobby-leave");
    this.privacyButton = page.getByTestId("lobby-privacy");

    this.mediaPanel = page.getByTestId("lobby-media-panel");
    this.remoteVideo = page.locator("#lobby-remote-video");
    this.localVideo = page.locator("#lobby-local-video");
    this.endCallButton = page.locator('[data-lobby-media-action="end-call"]');
    this.networkPanel = page.getByTestId("lobby-network-panel");
    this.filePanel = page.getByTestId("lobby-file-panel");
    this.fileInput = page.locator("#lobby-file-input");
    this.gamePanel = page.getByTestId("lobby-game-panel");
    this.gameConsent = page.getByTestId("lobby-game-consent");
    this.gameCanvas = page.locator("#lobby-game-canvas canvas");
    this.chat = page.getByTestId("lobby-chat");
    this.chatInput = this.chat.getByPlaceholder("Type a message");
    this.chatSendButton = this.chat.getByRole("button", {
      name: "Send",
      exact: true,
    });
    this.ended = page.getByTestId("lobby-ended");
    this.fileTransfer = this.filePanel.getByTestId("file-transfer");
    this.fileTransferAccept = this.filePanel.getByTestId(
      "file-transfer-accept",
    );
    this.muteButton = page.locator('[data-lobby-media-action="mute"]');
    this.cameraButton = page.locator('[data-lobby-media-action="camera"]');
    this.enableAudioButton = page.locator(
      '[data-lobby-media-action="enable-audio"]',
    );
    this.enableVideoButton = page.locator(
      '[data-lobby-media-action="enable-video"]',
    );
    // In the universal lobby, "add video" to an ongoing call is the same in-call
    // "turn on camera" control an auto-joined receiver uses.
    this.addVideoButton = this.enableVideoButton;
    this.peerMutedIndicator = page.getByTestId("lobby-peer-muted");
    this.peerCameraOffIndicator = page.getByTestId("lobby-peer-camera-off");
    this.networkHealth = page.getByTestId("lobby-network-health");
    this.mediaContainer = page.locator(".lobby-media");
    this.devicesButton = page.locator(
      '[data-lobby-media-action="device-settings"]',
    );
    this.devicesPanel = page.getByTestId("lobby-devices");
    this.fileValidationError = page.getByTestId("lobby-ft-validation-error");
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

  /**
   * The Start-menu call items enable only once the persistent WebRTC link is up.
   * `toBeEnabled` checks the disabled attribute without requiring the (hidden)
   * menu to be open.
   */
  async waitUntilConnected() {
    await expect(this.videoButton).toBeEnabled({ timeout: 35_000 });
  }

  /** Open the taskbar Start menu (idempotent). */
  async openStartMenu() {
    if (!(await this.startMenu.isVisible())) {
      await this.startButton.click();
    }
    await expect(this.startMenu).toBeVisible();
  }

  /**
   * Bring a window to the front via its taskbar button (always on top, never
   * occluded). Only clicks when the window isn't already focused, since clicking
   * the active window's taskbar button minimizes it.
   */
  private async focusWindow(id: string) {
    const btn = this.page.locator(`[data-window-taskbar="${id}"]`);
    const active = await btn.evaluate((el) =>
      el.classList.contains("is-active"),
    );
    if (!active) await btn.click();
  }

  async startVideoCall() {
    await this.sendVideo();
    await expect(this.remoteVideo).toBeVisible();
  }

  /** Click a window's title-bar X (close control). */
  async closeWindow(id: string) {
    await this.page
      .locator(`[data-window-id="${id}"] [data-window-control="close"]`)
      .click();
  }

  /**
   * Turn our camera on, whether we are the first mover (start from the Start menu)
   * or an auto-joined receiver (use the in-call "Turn on camera" control). Waits
   * for whichever path the universal lobby offers.
   */
  async sendVideo() {
    await expect
      .poll(
        async () =>
          (await this.enableVideoButton.isVisible()) ||
          (await this.videoButton.isEnabled()),
        { timeout: 15_000 },
      )
      .toBe(true);

    if (await this.enableVideoButton.isVisible()) {
      await this.enableVideoButton.click();
    } else {
      await this.clickStartVideo();
    }
  }

  /** Start video from the Start menu (first mover) without waiting for the remote. */
  async clickStartVideo() {
    await this.openStartMenu();
    await this.videoButton.click();
  }

  async startAudioCall() {
    await expect
      .poll(
        async () =>
          (await this.enableAudioButton.isVisible()) ||
          (await this.audioButton.isEnabled()),
        { timeout: 15_000 },
      )
      .toBe(true);

    if (await this.enableAudioButton.isVisible()) {
      await this.enableAudioButton.click();
    } else {
      await this.openStartMenu();
      await this.audioButton.click();
    }
  }

  async openGamePanel() {
    await this.openStartMenu();
    await this.gameMenuItem.click();
    await expect(this.gamePanel).toBeVisible();
  }

  async proposeGame(name: string) {
    await this.openGamePanel();
    await this.gamePanel.getByRole("button", { name }).click();
  }

  async acceptGame() {
    await expect(this.gameConsent).toBeVisible({ timeout: 15_000 });
    await this.gameConsent.getByRole("button", { name: "Accept" }).click();
  }

  async declineGame() {
    await expect(this.gameConsent).toBeVisible({ timeout: 15_000 });
    await this.gameConsent.getByRole("button", { name: "Decline" }).click();
  }

  async openFilePanel() {
    await this.openStartMenu();
    await this.fileMenuItem.click();
    await expect(this.filePanel).toBeVisible();
    await expect(this.fileInput).toBeAttached();
  }

  async sendFile(name: string, content: string) {
    await this.fileInput.setInputFiles({
      name,
      mimeType: "text/plain",
      buffer: Buffer.from(content),
    });
  }

  async leave() {
    await this.openStartMenu();
    await this.leaveButton.click();
  }

  async setLayout(label: string) {
    await this.mediaPanel
      .getByRole("button", { name: label, exact: true })
      .click();
  }

  /**
   * Reads the actual RTP state of the remote video element — `videoLive` is true
   * only when a remote video track exists AND is receiving packets (not muted).
   * This catches one-directional media that a visibility check would miss.
   */
  async remoteVideoLive(): Promise<boolean> {
    return this.page.evaluate(() => {
      const v = document.getElementById(
        "lobby-remote-video",
      ) as HTMLVideoElement | null;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const stream = v?.srcObject as any;
      const track = stream?.getVideoTracks?.()[0];
      return !!track && track.readyState === "live" && track.muted === false;
    });
  }

  async expectRemoteVideoFlowing() {
    await expect
      .poll(() => this.remoteVideoLive(), { timeout: 15_000 })
      .toBe(true);
  }

  async sendChat(text: string) {
    // Chat may sit behind other windows — bring it to the front before typing.
    await this.focusWindow("chat");
    await this.chatInput.fill(text);
    await this.chatSendButton.click();
  }

  async expectChatMessage(text: string) {
    await expect(this.chat).toContainText(text, { timeout: 10_000 });
  }

  /**
   * The persistent connection must outlive any single feature. The file/game Start
   * menu items stay enabled whenever connected (unlike audio/video, which disable
   * during an active call), so they are the reliable "still connected" signal.
   */
  async expectStillConnected() {
    await expect(this.ended).toHaveCount(0);
    await expect(this.fileMenuItem).toBeEnabled();
    await expect(this.gameMenuItem).toBeEnabled();
  }
}

export async function openLobbyFromInvite(
  sourcePage: Page,
  inviteLink: Locator,
): Promise<LobbyPage> {
  const popupPromise = sourcePage.waitForEvent("popup");
  await inviteLink.click();
  const page = await popupPromise;
  const lobby = new LobbyPage(page);
  await lobby.waitUntilOpen();
  return lobby;
}
