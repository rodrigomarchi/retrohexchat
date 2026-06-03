import { Locator, Page, expect } from '@playwright/test';

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function actionLabel(actionType: string): string {
  return actionType
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

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
  readonly lobbyChatInput: Locator;
  readonly lobbyChatSendButton: Locator;
  readonly audioCallButton: Locator;
  readonly videoCallButton: Locator;
  readonly sendFileButton: Locator;
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
    this.lobbyChatInput = this.root.getByPlaceholder('Type a message...');
    this.lobbyChatSendButton = this.root.getByRole('button', {
      name: 'Send',
      exact: true,
    });
    this.audioCallButton = page.getByRole('button', { name: 'Audio Call' });
    this.videoCallButton = page.getByRole('button', { name: 'Video Call' });
    this.sendFileButton = page.getByRole('button', { name: 'Send File' });
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

  async waitUntilBrowserOffline() {
    await expect
      .poll(
        () => this.page.evaluate(() => navigator.onLine),
        { timeout: 5_000 },
      )
      .toBe(false);
  }

  async waitUntilBrowserOnline() {
    await expect
      .poll(
        () => this.page.evaluate(() => navigator.onLine),
        { timeout: 5_000 },
      )
      .toBe(true);
  }

  async sendLobbyMessage(text: string) {
    await expect(this.lobbyChatInput).toBeEnabled();
    await this.lobbyChatInput.fill(text);
    await expect(this.lobbyChatSendButton).toBeEnabled();
    await this.lobbyChatInput.press('Enter');
    await expect(this.lobbyChatInput).toHaveValue('');
  }

  async expectLobbyMessage(text: string) {
    await expect(this.root.getByText(text, { exact: false }).first()).toBeVisible({
      timeout: 10_000,
    });
  }

  actionRequest(actionType: string): Locator {
    return this.page.getByText(
      new RegExp(`Action Request:\\s*${escapeRegExp(actionLabel(actionType))}`),
    );
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
