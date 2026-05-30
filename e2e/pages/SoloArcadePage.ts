import { Locator, Page, expect } from '@playwright/test';

export class SoloArcadePage {
  readonly page: Page;
  readonly root: Locator;
  readonly sessionEndButton: Locator;
  readonly sessionCloseButton: Locator;
  readonly sessionCompleteText: Locator;

  constructor(page: Page) {
    this.page = page;
    this.root = page.locator('#solo-lobby');
    this.sessionEndButton = page.getByTestId('solo-session-end');
    this.sessionCloseButton = page.getByTestId('solo-session-close');
    this.sessionCompleteText = page.getByText('Session Complete');
  }

  async waitUntilOpen() {
    await expect(this.page).toHaveURL(/\/solo\/[A-Za-z0-9_-]+$/);
    await expect(this.root).toBeVisible();
  }

  gameButton(gameId: string): Locator {
    return this.page.getByTestId(`solo-game-${gameId}`);
  }

  startButton(gameId: string): Locator {
    return this.page.getByTestId(`solo-game-start-${gameId}`);
  }

  async previewGame(gameId: string) {
    await expect(this.gameButton(gameId)).toBeVisible({ timeout: 10_000 });
    await this.gameButton(gameId).click();
  }

  async startGame(gameId: string): Promise<Page> {
    await expect(this.startButton(gameId)).toBeVisible({ timeout: 10_000 });
    const popupPromise = this.page.waitForEvent('popup');
    await this.startButton(gameId).click();
    return popupPromise;
  }

  async expectPlaying(gameName: string) {
    await expect(this.root).toContainText(gameName, { timeout: 10_000 });
    await expect(this.root).toContainText('Game in progress...', {
      timeout: 10_000,
    });
  }

  async expectFinished() {
    await expect(this.sessionCompleteText).toBeVisible({ timeout: 10_000 });
  }

  async close() {
    await expect(this.sessionCloseButton).toBeVisible({ timeout: 10_000 });
    await this.sessionCloseButton.click();
  }
}

export async function openSoloArcadeFromChat(
  sourcePage: Page,
  soloLink: Locator,
): Promise<SoloArcadePage> {
  const popupPromise = sourcePage.waitForEvent('popup');
  await soloLink.click();
  const page = await popupPromise;
  const solo = new SoloArcadePage(page);
  await solo.waitUntilOpen();
  return solo;
}
