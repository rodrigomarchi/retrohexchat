import { Locator, Page, expect } from '@playwright/test';

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

  constructor(page: Page) {
    this.page = page;
    this.lobby = page.getByTestId('game-lobby');
    this.acceptButton = page.getByTestId('game-lobby-accept');
    this.declineButton = page.getByTestId('game-lobby-decline');
    this.leaveButton = page.getByTestId('game-lobby-leave');
    this.canvas = page.getByTestId('game-canvas');
    this.canvasSurface = page.locator('#game-surface');
    this.endGameButton = page.getByTestId('game-canvas-end');
    this.sessionEnded = page.getByTestId('game-session-ended');
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
    await expect(this.canvas).toHaveAttribute('data-game-id', gameId);
    await expect(this.canvasSurface).toBeVisible();
  }

  async canvasFrameSignature(): Promise<string> {
    await expect(this.canvasSurface).toBeVisible();

    return this.canvasSurface.evaluate((node) => {
      const canvas = node as HTMLCanvasElement;
      const context = canvas.getContext('2d');
      if (!context) {
        return '0:0';
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
          return Number(signature.split(':')[0]);
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
  const popupPromise = sourcePage.waitForEvent('popup');
  await inviteLink.click();
  const page = await popupPromise;
  const session = new GameSessionPage(page);
  await session.waitUntilOpen();
  return session;
}
