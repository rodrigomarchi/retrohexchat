import { Locator, Page, expect } from "@playwright/test";

export class GameSessionPage {
  readonly page: Page;
  readonly lobby: Locator;
  readonly acceptButton: Locator;
  readonly declineButton: Locator;
  readonly leaveButton: Locator;
  readonly canvas: Locator;
  readonly canvasSurface: Locator;
  readonly endGameButton: Locator;
  readonly sessionEnded: Locator;
  readonly mediaDock: Locator;
  readonly startVoiceButton: Locator;
  readonly startVideoButton: Locator;
  readonly mediaCall: Locator;
  readonly remoteVideo: Locator;
  readonly localVideo: Locator;
  readonly remoteAudio: Locator;
  readonly muteButton: Locator;
  readonly cameraButton: Locator;
  readonly joinMediaButton: Locator;
  readonly layoutFocusButton: Locator;
  readonly layoutSideBySideButton: Locator;
  readonly layoutMaximizedButton: Locator;
  readonly endCallButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.lobby = page.getByTestId("game-lobby");
    this.acceptButton = page.getByTestId("game-lobby-accept");
    this.declineButton = page.getByTestId("game-lobby-decline");
    this.leaveButton = page.getByTestId("game-lobby-leave");
    this.canvas = page.getByTestId("game-canvas");
    this.canvasSurface = page.locator("#game-surface");
    this.endGameButton = page.getByTestId("game-canvas-end");
    this.sessionEnded = page.getByTestId("game-session-ended");
    this.mediaDock = page.getByTestId("game-media");
    this.startVoiceButton = page.getByTestId("game-media-start-audio");
    this.startVideoButton = page.getByTestId("game-media-start-video");
    this.mediaCall = page.getByTestId("game-media-call");
    this.remoteVideo = page.locator("#game-remote-video");
    this.localVideo = page.locator("#game-local-video");
    this.remoteAudio = page.locator("#game-remote-audio");
    this.muteButton = page.getByTestId("game-media-mute");
    this.cameraButton = page.getByTestId("game-media-camera");
    this.joinMediaButton = page.getByTestId("game-media-join");
    this.layoutFocusButton = page.getByTestId("game-media-layout-focus");
    this.layoutSideBySideButton = page.getByTestId(
      "game-media-layout-side-by-side",
    );
    this.layoutMaximizedButton = page.getByTestId(
      "game-media-layout-maximized",
    );
    this.endCallButton = page.getByTestId("game-media-end-call");
  }

  async waitUntilOpen() {
    await expect(this.page).toHaveURL(/\/game\/[A-Za-z0-9_-]+$/);
    await expect(this.lobby).toBeVisible();
  }

  gameButton(gameId: string): Locator {
    return this.page.getByTestId(`game-lobby-game-${gameId}`);
  }

  async selectGame(gameId: string) {
    await expect(this.gameButton(gameId)).toBeVisible({ timeout: 10_000 });
    await this.gameButton(gameId).click();
  }

  async acceptGame(gameName: string) {
    await expect(this.lobby).toContainText(`wants to play ${gameName}`, {
      timeout: 10_000,
    });
    await this.acceptButton.click();
  }

  async declineGame(gameName: string) {
    await expect(this.lobby).toContainText(`wants to play ${gameName}`, {
      timeout: 10_000,
    });
    await this.declineButton.click();
  }

  async leave() {
    await expect(this.leaveButton).toBeVisible();
    await this.leaveButton.click();
  }

  async expectGameCanvas(gameId: string) {
    await expect(this.canvas).toBeVisible({ timeout: 10_000 });
    await expect(this.canvas).toHaveAttribute("data-game-id", gameId);
    await expect(this.canvasSurface).toBeVisible();
  }

  async expectMediaIdle() {
    await expect(this.mediaDock).toBeVisible({ timeout: 10_000 });
    await expect(this.startVoiceButton).toBeVisible();
    await expect(this.startVideoButton).toBeVisible();
  }

  async expectVideoCallActive() {
    await expect(this.mediaCall).toBeVisible({ timeout: 15_000 });
    await expect(this.remoteVideo).toBeVisible();
    await expect(this.localVideo).toBeVisible();
    await expect(this.muteButton).toBeVisible();
    await expect(this.cameraButton).toBeVisible();
  }

  async expectIncomingVideoCall() {
    await expect(this.mediaCall).toBeVisible({ timeout: 15_000 });
    await expect(this.joinMediaButton).toBeVisible();
    await expect(this.remoteVideo).toBeVisible();
  }

  async expectLocalVideoStreamTracks() {
    await expect
      .poll(() => this.mediaTrackCounts(this.localVideo), { timeout: 15_000 })
      .toEqual({ audio: 1, video: 1 });
  }

  async expectRemoteVideoStreamTrack() {
    await expect
      .poll(async () => (await this.mediaTrackCounts(this.remoteVideo)).video, {
        timeout: 20_000,
      })
      .toBeGreaterThan(0);
  }

  async expectRemoteAudioTrack() {
    await expect
      .poll(async () => (await this.mediaTrackCounts(this.remoteAudio)).audio, {
        timeout: 20_000,
      })
      .toBeGreaterThan(0);
  }

  private async mediaTrackCounts(locator: Locator) {
    return locator.evaluate((node) => {
      const media = node as HTMLMediaElement;
      const stream = media.srcObject as MediaStream | null;

      return {
        audio:
          stream
            ?.getAudioTracks()
            .filter((track) => track.readyState === "live").length || 0,
        video:
          stream
            ?.getVideoTracks()
            .filter((track) => track.readyState === "live").length || 0,
      };
    });
  }

  async canvasFrameSignature(): Promise<string> {
    await expect(this.canvasSurface).toBeVisible();

    return this.canvasSurface.evaluate((node) => {
      const canvas = node as HTMLCanvasElement;
      const context = canvas.getContext("2d");
      if (!context) {
        return "0:0";
      }

      const { width, height } = canvas;
      const pixels = context.getImageData(0, 0, width, height).data;
      let painted = 0;
      let hash = 2166136261;

      for (let y = 0; y < height; y += 12) {
        for (let x = 0; x < width; x += 12) {
          const i = (y * width + x) * 4;
          const r = pixels[i] || 0;
          const g = pixels[i + 1] || 0;
          const b = pixels[i + 2] || 0;
          const a = pixels[i + 3] || 0;

          if (a > 0 && (r > 0 || g > 0 || b > 0)) {
            painted += 1;
          }

          hash ^= r;
          hash = Math.imul(hash, 16777619);
          hash ^= g;
          hash = Math.imul(hash, 16777619);
          hash ^= b;
          hash = Math.imul(hash, 16777619);
          hash ^= a;
          hash = Math.imul(hash, 16777619);
        }
      }

      return `${painted}:${hash >>> 0}`;
    });
  }

  async expectCanvasPainted() {
    await expect
      .poll(
        async () => {
          const signature = await this.canvasFrameSignature();
          return Number(signature.split(":")[0]);
        },
        { timeout: 15_000 },
      )
      .toBeGreaterThan(0);
  }

  async expectCanvasFrameChanged(previousSignature: string) {
    await expect
      .poll(() => this.canvasFrameSignature(), { timeout: 15_000 })
      .not.toBe(previousSignature);
  }
}

export async function openGameSessionFromInvite(
  sourcePage: Page,
  inviteLink: Locator,
): Promise<GameSessionPage> {
  const popupPromise = sourcePage.waitForEvent("popup");
  await inviteLink.click();
  const page = await popupPromise;
  const session = new GameSessionPage(page);
  await session.waitUntilOpen();
  return session;
}
