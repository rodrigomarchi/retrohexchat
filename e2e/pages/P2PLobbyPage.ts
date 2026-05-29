import { Locator, Page, expect } from '@playwright/test';

export class P2PLobbyPage {
  readonly page: Page;
  readonly root: Locator;
  readonly fileTransferHook: Locator;
  readonly fileInput: Locator;
  readonly fileTransfer: Locator;
  readonly fileTransferAcceptButton: Locator;
  readonly mediaCall: Locator;
  readonly audioCallButton: Locator;
  readonly sessionEnded: Locator;

  constructor(page: Page) {
    this.page = page;
    this.root = page.getByTestId('p2p-lobby');
    this.fileTransferHook = page.getByTestId('file-transfer-hook');
    this.fileInput = page.locator('#p2p-file-input');
    this.fileTransfer = page.getByTestId('file-transfer');
    this.fileTransferAcceptButton = page.getByTestId('file-transfer-accept');
    this.mediaCall = page.getByTestId('media-call');
    this.audioCallButton = page.getByRole('button', { name: 'Audio Call' });
    this.sessionEnded = page.getByTestId('p2p-session-ended');
  }

  async waitUntilOpen() {
    await expect(this.page).toHaveURL(/\/p2p\/[A-Za-z0-9_-]+$/);
    await expect(this.root).toBeVisible();
  }

  actionRequest(actionType: string): Locator {
    return this.page.getByText(`Action Request: ${actionType}`);
  }

  async acceptAction(actionType: string) {
    await expect(this.actionRequest(actionType)).toBeVisible({
      timeout: 10_000,
    });
    await this.page.getByRole('button', { name: 'Accept' }).click();
  }

  async declineAction(actionType: string) {
    await expect(this.actionRequest(actionType)).toBeVisible({
      timeout: 10_000,
    });
    await this.page.getByRole('button', { name: 'Decline' }).click();
  }
}

export async function openP2PLobbyFromInvite(
  sourcePage: Page,
  inviteLink: Locator,
): Promise<P2PLobbyPage> {
  const popupPromise = sourcePage.waitForEvent('popup');
  await inviteLink.click();
  const page = await popupPromise;
  const lobby = new P2PLobbyPage(page);
  await lobby.waitUntilOpen();
  return lobby;
}
