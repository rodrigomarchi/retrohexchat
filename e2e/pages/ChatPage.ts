import { Page, Locator, expect } from '@playwright/test';

// Page Object for the v2 ChatLive at /chat. Covers high-level shell
// concerns shared by specs (waiting for connect, opening the File menu,
// disconnecting). Channel/PM/IRC interactions will live on dedicated POMs
// once we have specs that need them.
export class ChatPage {
  readonly page: Page;
  readonly menuBar: Locator;
  readonly fileMenuTrigger: Locator;
  readonly viewMenuTrigger: Locator;
  readonly helpMenuTrigger: Locator;
  readonly toolsMenuTrigger: Locator;
  readonly disconnectMenuItem: Locator;
  readonly findMenuItem: Locator;
  readonly helpTopicsMenuItem: Locator;
  readonly addressBookMenuItem: Locator;
  readonly channelCentralMenuItem: Locator;
  readonly aliasEditorMenuItem: Locator;
  readonly disconnectConfirmDialog: Locator;
  readonly disconnectConfirmButton: Locator;
  readonly kickDialogOkButton: Locator;
  readonly chatInput: Locator;
  readonly chatSendButton: Locator;
  readonly charCounter: Locator;
  readonly messageList: Locator;
  readonly messageRows: Locator;
  readonly statusMessageList: Locator;
  readonly nicklist: Locator;
  readonly topicBar: Locator;
  readonly tabBar: Locator;
  readonly formatBoldButton: Locator;
  readonly formatItalicButton: Locator;
  readonly formatUnderlineButton: Locator;
  readonly formatColorButton: Locator;
  readonly formatReverseButton: Locator;
  readonly formatResetButton: Locator;
  readonly stripFormattingToggle: Locator;
  readonly emojiPickerToggle: Locator;
  readonly emojiPicker: Locator;
  readonly emojiPickerSearch: Locator;
  readonly autocompleteDropdown: Locator;
  readonly inlineHelp: Locator;
  readonly syntaxTooltip: Locator;
  readonly historySearch: Locator;
  readonly historySearchInput: Locator;
  readonly historySearchNoResults: Locator;
  readonly searchBar: Locator;
  readonly searchBarInput: Locator;
  readonly searchBarCount: Locator;
  readonly searchBarPrevButton: Locator;
  readonly searchBarNextButton: Locator;
  readonly searchBarCaseSensitive: Locator;
  readonly searchBarRegex: Locator;
  readonly searchBarMyMentions: Locator;
  readonly searchBarHistory: Locator;
  readonly searchHighlights: Locator;
  readonly searchActiveHighlight: Locator;
  readonly pasteConfirmDialog: Locator;
  readonly pasteConfirmSendButton: Locator;
  readonly pasteConfirmCancelButton: Locator;
  readonly pasteFloodWarning: Locator;
  readonly chatContextMenu: Locator;
  readonly contextReplyMenuItem: Locator;
  readonly replyBar: Locator;
  readonly replyBarDismissButton: Locator;
  readonly replyBlock: Locator;
  readonly helpContentPane: Locator;
  readonly notifyListDialog: Locator;
  readonly addressBookDialog: Locator;
  readonly channelCentralDialog: Locator;
  readonly aliasDialog: Locator;
  readonly customMenusDialog: Locator;
  readonly botManagementDialog: Locator;
  readonly botList: Locator;
  readonly newBotDialog: Locator;
  readonly addCommandDialog: Locator;
  readonly nickChangeDialog: Locator;
  readonly nickChangePassword: Locator;
  readonly nickChangeConfirmButton: Locator;
  readonly nickChangeCancelButton: Locator;
  readonly nickChangeError: Locator;
  readonly channelListSearch: Locator;
  readonly channelListJoinButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.menuBar = page.getByTestId('menu-bar');
    this.chatInput = page.getByTestId('chat-input-field');
    this.chatSendButton = page.getByTestId('chat-input-send');
    this.charCounter = page.getByTestId('char-counter');
    this.messageList = page.getByTestId('chat-message-list');
    this.messageRows = this.messageList.locator('[data-message-id]');
    this.statusMessageList = page.getByTestId('status-messages');
    this.nicklist = page.getByTestId('nicklist');
    this.topicBar = page.getByTestId('topic-bar');
    this.tabBar = page.getByTestId('tab-bar');
    this.formatBoldButton = page.getByTestId('format-btn-bold');
    this.formatItalicButton = page.getByTestId('format-btn-italic');
    this.formatUnderlineButton = page.getByTestId('format-btn-underline');
    this.formatColorButton = page.getByTestId('format-btn-color');
    this.formatReverseButton = page.getByTestId('format-btn-reverse');
    this.formatResetButton = page.getByTestId('format-btn-reset');
    this.stripFormattingToggle = page.getByTestId('strip-formatting-toggle');
    this.emojiPickerToggle = page.getByTestId('emoji-picker-toggle');
    this.emojiPicker = page.getByTestId('emoji-picker');
    this.emojiPickerSearch = page.getByTestId('emoji-picker-search');
    this.autocompleteDropdown = page.getByTestId('autocomplete-dropdown');
    // menu_bar_app renders one <button data-menubar-trigger> per top-level
    // label; we filter by visible label text rather than rely on order.
    this.fileMenuTrigger = page
      .locator('button[data-menubar-trigger]')
      .filter({ hasText: 'File' });
    this.viewMenuTrigger = page
      .locator('button[data-menubar-trigger]')
      .filter({ hasText: 'View' });
    this.helpMenuTrigger = page
      .locator('button[data-menubar-trigger]')
      .filter({ hasText: 'Help' });
    this.toolsMenuTrigger = page
      .locator('button[data-menubar-trigger]')
      .filter({ hasText: 'Tools' });
    // context_menu_item exposes data-testid="context-menu-item-<action>".
    this.disconnectMenuItem = page.getByTestId('context-menu-item-disconnect');
    this.findMenuItem = page.getByTestId('context-menu-item-toggle_search');
    this.helpTopicsMenuItem = page.getByTestId(
      'context-menu-item-help_topics',
    );
    this.addressBookMenuItem = page.getByTestId(
      'context-menu-item-toggle_address_book',
    );
    this.channelCentralMenuItem = page.getByTestId(
      'context-menu-item-open_channel_central',
    );
    this.aliasEditorMenuItem = page.getByTestId(
      'context-menu-item-open_alias_dialog',
    );
    this.inlineHelp = page.getByTestId('inline-help');
    this.syntaxTooltip = page.getByTestId('syntax-tooltip');
    this.historySearch = page.getByTestId('history-search');
    this.historySearchInput = page.getByTestId('history-search-input');
    this.historySearchNoResults = page.getByTestId('history-search-no-results');
    this.searchBar = page.getByTestId('search-bar');
    this.searchBarInput = page.getByTestId('search-bar-input');
    this.searchBarCount = page.getByTestId('search-bar-count');
    this.searchBarPrevButton = page.getByTestId('search-bar-prev');
    this.searchBarNextButton = page.getByTestId('search-bar-next');
    this.searchBarCaseSensitive = page.getByTestId(
      'search-bar-case-sensitive',
    );
    this.searchBarRegex = page.getByTestId('search-bar-regex');
    this.searchBarMyMentions = page.getByTestId('search-bar-my-mentions');
    this.searchBarHistory = page.getByTestId('search-bar-history');
    this.searchHighlights = page.locator('mark.search-highlight');
    this.searchActiveHighlight = page.locator('mark.search-highlight-active');
    this.pasteConfirmDialog = page.getByTestId('paste-confirm-dialog');
    this.pasteConfirmSendButton = page.getByTestId('paste-confirm-send');
    this.pasteConfirmCancelButton = page.getByTestId('paste-confirm-cancel');
    this.pasteFloodWarning = page.getByTestId('paste-flood-warning');
    this.chatContextMenu = page.getByTestId('context-menu-chat-context-menu');
    this.contextReplyMenuItem = page.getByTestId(
      'context-menu-item-reply_to_message',
    );
    this.replyBar = page.getByTestId('reply-bar');
    this.replyBarDismissButton = page.getByTestId('reply-bar-dismiss');
    this.replyBlock = page.getByTestId('reply-block');
    this.helpContentPane = page.getByTestId('help-content-pane');
    this.notifyListDialog = page.locator('#notify-list-dialog [role="dialog"]');
    this.addressBookDialog = page.locator(
      '#address-book-dialog [role="dialog"]',
    );
    this.channelCentralDialog = page.locator(
      '#channel-central-dialog [role="dialog"]',
    );
    this.aliasDialog = page.locator('#alias-dialog [role="dialog"]');
    this.customMenusDialog = page.locator(
      '#custom-menus-dialog [role="dialog"]',
    );
    this.botManagementDialog = page.locator(
      '#bot-management-dialog [role="dialog"]',
    );
    this.botList = page.getByTestId('bot-list');
    this.newBotDialog = page.locator('#new-bot-dialog [role="dialog"]');
    this.addCommandDialog = page.locator(
      '#add-command-dialog [role="dialog"]',
    );
    this.nickChangeDialog = page.getByTestId('nick-change-dialog');
    this.nickChangePassword = page.getByTestId('nick-change-password');
    this.nickChangeConfirmButton = page.getByTestId('nick-change-confirm');
    this.nickChangeCancelButton = page.getByTestId('nick-change-cancel');
    this.nickChangeError = page.getByTestId('nick-change-error');
    this.channelListSearch = page.getByTestId('channel-list-search');
    this.channelListJoinButton = page.getByTestId('channel-list-join');
    // The dialog component wraps content in a <span data-testid="...">, but
    // that wrapper has zero visible size when the dialog is closed; use the
    // confirm button instead as the open/closed signal.
    this.disconnectConfirmDialog = page.getByTestId(
      'disconnect-confirm-dialog-confirm',
    );
    this.disconnectConfirmButton = page.getByTestId(
      'disconnect-confirm-dialog-confirm',
    );
    this.kickDialogOkButton = page.getByTestId('kick-dialog-ok');
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

  // Switches to the Status tab (server-level messages like welcome, MOTD,
  // NickServ acks). Channel tabs live alongside Status in the same tablist.
  async switchToStatusTab() {
    await this.page.getByRole('tab', { name: 'Status' }).click();
  }

  // Returns the tab element with the given visible label (e.g. "#lobby").
  // Names with leading "#" need no special escaping here — Playwright's
  // accessible-name match works literally.
  tab(name: string): Locator {
    return this.page.getByRole('tab', { name, exact: false });
  }

  async switchToTab(name: string) {
    await this.tab(name).click();
  }

  // Each tab contains a nested "Close tab" button.
  async closeTab(name: string) {
    await this.tab(name).getByRole('button', { name: 'Close tab' }).click();
  }

  async openSearchFromViewMenu() {
    await this.viewMenuTrigger.click();
    await expect(this.findMenuItem).toBeVisible();
    await this.findMenuItem.click();
    await expect(this.searchBar).toBeVisible();
  }

  async expectTabVisible(name: string) {
    await expect(this.tab(name)).toBeVisible();
  }

  async expectTabSelected(name: string) {
    await expect(this.tab(name)).toHaveAttribute('aria-selected', 'true');
  }

  async expectTabHidden(name: string) {
    await expect(this.tab(name)).toHaveCount(0);
  }

  // Types a message (or slash command) into the chat input and submits
  // by pressing Enter. The form's phx-submit handler dispatches commands
  // through the same path real users hit when typing `/...`.
  async sendMessage(text: string) {
    await expect(this.chatInput).toBeEnabled();
    await this.chatInput.fill(text);
    await this.chatInput.press('Enter');
  }

  async pasteText(text: string) {
    await expect(this.chatInput).toBeEnabled();
    await this.chatInput.focus();
    await this.chatInput.evaluate((el, pasted) => {
      const clipboard = new DataTransfer();
      clipboard.setData('text/plain', pasted);
      const event = new ClipboardEvent('paste', {
        bubbles: true,
        cancelable: true,
        clipboardData: clipboard,
      });
      el.dispatchEvent(event);
    }, text);
  }

  // Asserts that a message with the given visible text is present in the
  // active channel/PM message list. Use the message body verbatim — there
  // are no per-message testids so we match by text content scoped to the
  // chat-message-list container. Uses .first() to tolerate other messages
  // (e.g., system "you are now identified as <nick>") that may also match.
  async expectMessageVisible(text: string, timeout?: number) {
    await expect(
      this.messageList.getByText(text, { exact: false }).first(),
    ).toBeVisible(timeout ? { timeout } : undefined);
  }

  async expectMessageHidden(text: string) {
    await expect(this.messageList.getByText(text, { exact: false })).toHaveCount(
      0,
    );
  }

  async expectMessageNotVisible(text: string) {
    await expect(
      this.messageList.getByText(text, { exact: false }).first(),
    ).toBeHidden();
  }

  messageRowByText(text: string): Locator {
    return this.messageRows.filter({ hasText: text }).first();
  }

  async openMessageContextMenu(text: string) {
    await this.messageRowByText(text).click({ button: 'right' });
    await expect(this.chatContextMenu).toBeVisible();
  }

  async expectActiveMessageCount(count: number) {
    await expect(this.messageRows).toHaveCount(count);
  }

  async expectStatusMessageVisible(text: string, timeout?: number) {
    await expect(
      this.statusMessageList.getByText(text, { exact: false }).first(),
    ).toBeVisible(timeout ? { timeout } : undefined);
  }

  async expectStatusMessageHidden(text: string, timeout = 1_000) {
    await expect(
      this.statusMessageList.getByText(text, { exact: false }),
    ).toHaveCount(0, { timeout });
  }

  // Per-nick nicklist item — uses the data-testid="nicklist-item-<nick>"
  // attribute set by the Nicklist component.
  nicklistItem(nick: string): Locator {
    return this.page.getByTestId(`nicklist-item-${nick}`);
  }

  async expectNickInList(nick: string) {
    await expect(this.nicklistItem(nick)).toBeVisible();
  }

  async expectNickNotInList(nick: string) {
    await expect(this.nicklistItem(nick)).toHaveCount(0);
  }

  async expectNickRole(
    nick: string,
    role: 'owner' | 'operator' | 'half_operator' | 'voiced' | 'regular',
  ) {
    await expect(this.nicklistItem(nick)).toHaveAttribute('data-role', role);
  }

  async expectAutocompleteContains(text: string) {
    await expect(this.autocompleteDropdown).toBeVisible();
    await expect(this.autocompleteDropdown).toContainText(text);
  }

  async dismissKickDialog() {
    await expect(this.kickDialogOkButton).toBeVisible();
    await this.kickDialogOkButton.click();
    await expect(this.kickDialogOkButton).toBeHidden();
  }

  autocompleteItemByText(text: string): Locator {
    return this.autocompleteDropdown
      .locator('[data-testid^="autocomplete-item-"]')
      .filter({ hasText: text })
      .first();
  }

  inviteJoinButton(channel: string): Locator {
    return this.page.getByTestId(`invite-join-${channel}`);
  }

  async acceptInvite(channel: string) {
    const button = this.inviteJoinButton(channel);
    await expect(button).toBeVisible();
    await button.click();
  }

  async expectInviteHidden(channel: string) {
    await expect(this.inviteJoinButton(channel)).toHaveCount(0, {
      timeout: 1_000,
    });
  }

  channelListRow(channel: string): Locator {
    return this.page.getByTestId(`channel-list-row-${channel}`);
  }

  notifyListRow(nick: string): Locator {
    return this.page.getByTestId(`notify-list-row-${nick}`);
  }

  addressBookNotifyRow(nick: string): Locator {
    return this.page.locator(`[id="ab-notify-entry-${nick}"]`);
  }

  aliasRow(name: string): Locator {
    return this.aliasDialog.locator('tr').filter({ hasText: `/${name}` });
  }

  customMenuRow(label: string): Locator {
    return this.customMenusDialog.locator('tr').filter({ hasText: label });
  }

  botItem(name: string): Locator {
    return this.page.getByTestId(`bot-item-${name}`);
  }

  arcadeSessionLink(): Locator {
    return this.messageList.getByRole('link', { name: 'Open Arcade' }).first();
  }

  p2pInviteCard(): Locator {
    return this.messageList.getByTestId('p2p-invite-card').first();
  }

  emojiButton(char: string): Locator {
    return this.emojiPicker.getByRole('button', { name: char });
  }

  formatColorSwatch(index: number): Locator {
    return this.page.getByTestId(`format-color-swatch-${index}`);
  }

  customContextMenuItem(label: string): Locator {
    return this.page
      .getByTestId('context-menu-item-custom_menu_execute')
      .filter({ hasText: label })
      .first();
  }

  channelConversationItem(channel: string): Locator {
    return this.page.getByTestId(`channel-${channel}`);
  }

  async openFileMenu() {
    // MenuBarHook listens for mousedown (not click) so that focus never
    // leaves the chat input. Playwright's click() does fire mousedown as
    // part of the click sequence, so a normal click is sufficient — but
    // we DO need the hook to be mounted first (see waitUntilConnected).
    await this.fileMenuTrigger.click();
    await expect(this.disconnectMenuItem).toBeVisible();
  }

  async openHelpTopicsFromMenu() {
    await this.helpMenuTrigger.click();
    await expect(this.helpTopicsMenuItem).toBeVisible();
    await this.helpTopicsMenuItem.click();
    await expect(this.page).toHaveURL(/\/chat\/help(\?.*)?$/);
    await expect(this.helpContentPane).toBeVisible();
  }

  async openChannelCentralFromMenu() {
    await this.toolsMenuTrigger.click();
    await expect(this.channelCentralMenuItem).toBeVisible();
    await this.channelCentralMenuItem.click();
    await expect(this.channelCentralDialog).toBeVisible();
  }

  async openAddressBookFromMenu() {
    await this.toolsMenuTrigger.click();
    await expect(this.addressBookMenuItem).toBeVisible();
    await this.addressBookMenuItem.click();
    await expect(this.addressBookDialog).toBeVisible();
  }

  async openAliasEditorFromMenu() {
    await this.toolsMenuTrigger.click();
    await expect(this.aliasEditorMenuItem).toBeVisible();
    await this.aliasEditorMenuItem.click();
    await expect(this.aliasDialog).toBeVisible();
  }

  async switchAddressBookToNotifyTab() {
    await this.addressBookDialog
      .getByRole('button', { name: 'Notify' })
      .click();
  }

  async closeAddressBook() {
    await this.addressBookDialog.getByRole('button', { name: 'OK' }).click();
    await expect(this.addressBookDialog).toBeHidden();
  }

  async closeNotifyList() {
    await this.notifyListDialog
      .getByRole('button', { name: 'Close' })
      .last()
      .click();
    await expect(this.notifyListDialog).toBeHidden();
  }

  async closeChannelCentral() {
    await this.channelCentralDialog
      .getByRole('button', { name: 'Close' })
      .last()
      .click();
    await expect(this.channelCentralDialog).toBeHidden();
  }

  async addAliasFromDialog(name: string, expansion: string) {
    await this.aliasDialog.getByRole('button', { name: 'Add' }).click();
    await this.aliasDialog.locator('input[name="name"]').fill(name);
    await this.aliasDialog.locator('input[name="expansion"]').fill(expansion);
    await this.aliasDialog.getByRole('button', { name: 'Save' }).click();
    await expect(this.aliasRow(name)).toContainText(expansion);
  }

  async editAliasFromDialog(name: string, expansion: string) {
    await this.aliasRow(name).click();
    await this.aliasDialog.getByRole('button', { name: 'Edit' }).click();
    await this.aliasDialog.locator('input[name="expansion"]').fill(expansion);
    await this.aliasDialog.getByRole('button', { name: 'Save' }).click();
    await expect(this.aliasRow(name)).toContainText(expansion);
  }

  async removeAliasFromDialog(name: string) {
    await this.aliasRow(name).click();
    await this.aliasDialog.getByRole('button', { name: 'Remove' }).click();
    await expect(this.aliasRow(name)).toHaveCount(0);
  }

  async closeAliasEditor() {
    await this.aliasDialog.getByRole('button', { name: 'Close' }).last().click();
    await expect(this.aliasDialog).toBeHidden();
  }

  async openCustomMenusDialogFromCommand() {
    await this.sendMessage('/popups');
    await expect(this.customMenusDialog).toBeVisible();
  }

  async addCustomMenuItem(
    tab: 'Nicklist' | 'Channel' | 'Chat',
    label: string,
    command: string,
  ) {
    await this.customMenusDialog.getByRole('button', { name: tab }).click();
    await this.customMenusDialog.getByRole('button', { name: 'Add' }).click();
    const form = this.customMenusDialog.locator('form:visible');

    await form.locator('input[name="label"]').fill(label);
    await form.locator('input[name="command"]').fill(command);
    await form.getByRole('button', { name: 'Save' }).click();
    await expect(this.customMenuRow(label)).toContainText(command);
  }

  async closeCustomMenusDialog() {
    await this.customMenusDialog.getByRole('button', { name: 'OK' }).click();
    await expect(this.customMenusDialog).toBeHidden();
  }

  async confirmNickChange(password?: string) {
    await expect(this.nickChangeDialog).toBeVisible();

    if (password !== undefined) {
      await expect(this.nickChangePassword).toBeVisible();
      await this.nickChangePassword.fill('');
      await this.nickChangePassword.pressSequentially(password);
    }

    await this.nickChangeConfirmButton.click();
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
