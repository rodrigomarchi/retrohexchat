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

  async expectGameCanvas(gameId: string) {
    await expect(this.canvas).toBeVisible({ timeout: 10_000 });
    await expect(this.canvas).toHaveAttribute('data-game-id', gameId);
    await expect(this.canvasSurface).toBeVisible();
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
