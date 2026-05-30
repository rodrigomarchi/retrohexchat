import { Locator, Page, expect } from '@playwright/test';

export class P2PLobbyPage {
  readonly page: Page;
  readonly root: Locator;
  readonly fileTransferHook: Locator;
  readonly fileInput: Locator;
  readonly fileTransfer: Locator;
  readonly fileTransferAcceptButton: Locator;
  readonly fileTransferCancelButton: Locator;
  readonly fileTransferStatus: Locator;
  readonly fileTransferValidationError: Locator;
  readonly mediaCall: Locator;
  readonly audioCallButton: Locator;
  readonly videoCallButton: Locator;
  readonly muteButton: Locator;
  readonly cameraButton: Locator;
  readonly peerMutedIndicator: Locator;
  readonly peerCameraOffIndicator: Locator;
  readonly acceptActionButton: Locator;
  readonly declineActionButton: Locator;
  readonly closeSessionButton: Locator;
  readonly sessionEnded: Locator;

  constructor(page: Page) {
    this.page = page;
    this.root = page.getByTestId('p2p-lobby');
    this.fileTransferHook = page.getByTestId('file-transfer-hook');
    this.fileInput = page.locator('#p2p-file-input');
    this.fileTransfer = page.getByTestId('file-transfer');
    this.fileTransferAcceptButton = page.getByTestId('file-transfer-accept');
    this.fileTransferCancelButton = page.getByTestId('file-transfer-cancel');
    this.fileTransferStatus = page.getByTestId('file-transfer-status');
    this.fileTransferValidationError = page.getByTestId(
      'file-transfer-validation-error',
    );
    this.mediaCall = page.getByTestId('media-call');
    this.audioCallButton = page.getByRole('button', { name: 'Audio Call' });
    this.videoCallButton = page.getByRole('button', { name: 'Video Call' });
    this.muteButton = page.getByTestId('media-controls-mute');
    this.cameraButton = page.getByTestId('media-controls-camera');
    this.peerMutedIndicator = page.getByTestId('media-peer-muted-indicator');
    this.peerCameraOffIndicator = page.getByTestId(
      'media-peer-camera-off-indicator',
    );
    this.acceptActionButton = page.getByRole('button', { name: 'Accept' });
    this.declineActionButton = page.getByRole('button', { name: 'Decline' });
    this.closeSessionButton = page.getByRole('button', {
      name: 'Close Session',
    });
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
    await this.acceptActionButton.click();
  }

  async declineAction(actionType: string) {
    await expect(this.actionRequest(actionType)).toBeVisible({
      timeout: 10_000,
    });
    await this.declineActionButton.click();
  }

  async doubleAcceptAction(actionType: string) {
    await expect(this.actionRequest(actionType)).toBeVisible({
      timeout: 10_000,
    });
    await this.acceptActionButton.dblclick();
  }

  async doubleDeclineAction(actionType: string) {
    await expect(this.actionRequest(actionType)).toBeVisible({
      timeout: 10_000,
    });
    await this.declineActionButton.dblclick();
  }

  async closeSession() {
    await expect(this.closeSessionButton).toBeVisible();
    await this.closeSessionButton.click();
  }

  async expectFileCancelled(fileName: string) {
    await expect(this.fileTransfer).toContainText(fileName, { timeout: 10_000 });
    await expect(this.fileTransferStatus).toContainText('Cancelled', {
      timeout: 10_000,
    });
    await expect(this.fileTransferStatus).not.toContainText('Failed');
    await expect(this.fileTransferAcceptButton).toHaveCount(0);
    await expect(this.fileTransferCancelButton).toHaveCount(0);
  }

  async expectFileValidationError(pattern: string | RegExp) {
    await expect(this.fileTransferValidationError).toBeVisible({
      timeout: 10_000,
    });
    await expect(this.fileTransferValidationError).toContainText(pattern);
    await expect(this.fileInput).toBeAttached();
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
