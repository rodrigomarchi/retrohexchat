import { Page, Locator, expect } from '@playwright/test';

// Page Object for the v2 ChatLive at /chat. Covers high-level shell
// concerns shared by specs (waiting for connect, opening the File menu,
// disconnecting). Channel/PM/IRC interactions will live on dedicated POMs
// once we have specs that need them.
export class ChatPage {
  readonly page: Page;
  readonly menuBar: Locator;
  readonly fileMenuTrigger: Locator;
  readonly disconnectMenuItem: Locator;
  readonly disconnectConfirmDialog: Locator;
  readonly disconnectConfirmButton: Locator;
  readonly chatInput: Locator;

  constructor(page: Page) {
    this.page = page;
    this.menuBar = page.getByTestId('menu-bar');
    this.chatInput = page.getByTestId('chat-input-field');
    // menu_bar_app renders one <button data-menubar-trigger> per top-level
    // label; we filter by visible label text rather than rely on order.
    this.fileMenuTrigger = page
      .locator('button[data-menubar-trigger]')
      .filter({ hasText: 'File' });
    // context_menu_item exposes data-testid="context-menu-item-<action>".
    this.disconnectMenuItem = page.getByTestId('context-menu-item-disconnect');
    // The dialog component wraps content in a <span data-testid="...">, but
    // that wrapper has zero visible size when the dialog is closed; use the
    // confirm button instead as the open/closed signal.
    this.disconnectConfirmDialog = page.getByTestId(
      'disconnect-confirm-dialog-confirm',
    );
    this.disconnectConfirmButton = page.getByTestId(
      'disconnect-confirm-dialog-confirm',
    );
  }

  // Waits until we are at /chat AND the LiveView socket is connected
  // (the File menu trigger is enabled and MenuBarHook has mounted).
  // The MenuBarHook is what makes clicking File open the dropdown — without
  // it the click is a no-op, so we wait for a phx-hook root with the live
  // session attribute to confirm hooks have wired up.
  async waitUntilConnected() {
    await expect(this.page).toHaveURL(/\/chat(\?.*)?$/);
    await expect(this.menuBar).toBeVisible();
    await expect(this.fileMenuTrigger).toBeEnabled();
    // Phoenix LiveView exposes window.liveSocket once initialized.
    // isConnected() returns true after the WebSocket handshake — at that
    // point phx-hook mounted() callbacks (including MenuBarHook) have run.
    await this.page.waitForFunction(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      () => !!(window as any).liveSocket?.isConnected?.(),
      { timeout: 10_000 },
    );
  }

  // Types a message (or slash command) into the chat input and submits
  // by pressing Enter. The form's phx-submit handler dispatches commands
  // through the same path real users hit when typing `/...`.
  async sendMessage(text: string) {
    await expect(this.chatInput).toBeEnabled();
    await this.chatInput.fill(text);
    await this.chatInput.press('Enter');
  }

  async openFileMenu() {
    // MenuBarHook listens for mousedown (not click) so that focus never
    // leaves the chat input. Playwright's click() does fire mousedown as
    // part of the click sequence, so a normal click is sufficient — but
    // we DO need the hook to be mounted first (see waitUntilConnected).
    await this.fileMenuTrigger.click();
    await expect(this.disconnectMenuItem).toBeVisible();
  }

  async disconnect() {
    await this.openFileMenu();
    await this.disconnectMenuItem.click();
    await expect(this.disconnectConfirmDialog).toBeVisible();
    await this.disconnectConfirmButton.click();
    // confirm_disconnect handler pushes the intentional_disconnect event,
    // a JS hook navigates to /chat/session/clear?reason=disconnected, and
    // SessionController redirects to /connect?reason=disconnected.
    await expect(this.page).toHaveURL(/\/connect(\?.*)?$/);
  }
}
