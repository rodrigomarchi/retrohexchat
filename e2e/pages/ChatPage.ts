import { Page, Locator, expect } from "@playwright/test";

export type AddressBookControlType =
  | "all"
  | "messages"
  | "pms"
  | "actions"
  | "notices"
  | "invites";

type ChannelCentralTab = "general" | "modes" | "access_lists" | "registration";

// The Access Lists tab holds all three per-channel lists behind a type selector.
type ChannelCentralAccessList = "bans" | "ban_exceptions" | "invite_exceptions";

type ChannelCentralModeLabel =
  | "Moderated (+m)"
  | "Invite Only (+i)"
  | "Topic Lock (+t)";

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function visibleContextMenuItem(page: Page, action: string): Locator {
  return page.getByTestId(`context-menu-item-${action}`).filter({
    visible: true,
  });
}

// Page Object for the app ChatLive at /chat. Covers high-level shell
// concerns shared by specs (waiting for connect, opening the File menu,
// disconnecting). Channel/PM/IRC interactions will live on dedicated POMs
// once we have specs that need them.
export class ChatPage {
  readonly page: Page;
  readonly menuBar: Locator;
  readonly fileMenuTrigger: Locator;
  readonly editMenuTrigger: Locator;
  readonly viewMenuTrigger: Locator;
  readonly helpMenuTrigger: Locator;
  readonly toolsMenuTrigger: Locator;
  readonly gamesMenuTrigger: Locator;
  readonly arcadeMenuItem: Locator;
  readonly arcadeWindow: Locator;
  readonly disconnectMenuItem: Locator;
  readonly adminSubmenuTrigger: Locator;
  readonly adminConsoleMenuItem: Locator;
  readonly adminUsersMenuItem: Locator;
  readonly adminChannelsMenuItem: Locator;
  readonly accountRegisterMenuItem: Locator;
  readonly accountIdentifyMenuItem: Locator;
  readonly accountProfileMenuItem: Locator;
  readonly accountAwayMenuItem: Locator;
  readonly accountUserModesMenuItem: Locator;
  readonly accountInfoMenuItem: Locator;
  readonly clearWindowMenuItem: Locator;
  readonly copySelectionMenuItem: Locator;
  readonly channelListMenuItem: Locator;
  readonly toggleConversationsMenuItem: Locator;
  readonly toggleNicklistMenuItem: Locator;
  readonly notifyListMenuItem: Locator;
  readonly findMenuItem: Locator;
  readonly helpTopicsMenuItem: Locator;
  readonly cheatsheetMenuItem: Locator;
  readonly aboutMenuItem: Locator;
  readonly addressBookMenuItem: Locator;
  readonly nickColorsMenuItem: Locator;
  readonly ignoreListMenuItem: Locator;
  readonly highlightWordsMenuItem: Locator;
  readonly channelCentralMenuItem: Locator;
  readonly performMenuItem: Locator;
  readonly autojoinMenuItem: Locator;
  readonly soundSettingsMenuItem: Locator;
  readonly aliasEditorMenuItem: Locator;
  readonly floodProtectionMenuItem: Locator;
  readonly customMenusMenuItem: Locator;
  readonly autorespondMenuItem: Locator;
  readonly timersMenuItem: Locator;
  readonly urlCatcherMenuItem: Locator;
  readonly userLookupMenuItem: Locator;
  readonly botManagementMenuItem: Locator;
  readonly messageOfTheDayMenuItem: Locator;
  readonly disconnectConfirmDialog: Locator;
  readonly disconnectConfirmButton: Locator;
  readonly kickDialogOkButton: Locator;
  readonly chatInput: Locator;
  readonly chatSendButton: Locator;
  readonly charCounter: Locator;
  readonly appLogo: Locator;
  readonly statusBarApp: Locator;
  readonly statusBarMuteToggle: Locator;
  readonly statusBarNotifyBadge: Locator;
  readonly connectionStatusHook: Locator;
  readonly connectionBanner: Locator;
  readonly reconnectOverlay: Locator;
  readonly reconnectOverlayAction: Locator;
  readonly messageList: Locator;
  readonly messageRows: Locator;
  readonly statusMessageList: Locator;
  readonly nicklist: Locator;
  readonly topicBar: Locator;
  readonly tabBar: Locator;
  readonly formattingToolbarToggle: Locator;
  readonly formattingToolbarPanel: Locator;
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
  readonly contextCopyMessageMenuItem: Locator;
  readonly contextReplyMenuItem: Locator;
  readonly contextEditMenuItem: Locator;
  readonly contextDeleteMenuItem: Locator;
  readonly chatContextCallMenuItem: Locator;
  readonly chatContextVideoCallMenuItem: Locator;
  readonly chatContextSendFileMenuItem: Locator;
  readonly chatContextGameMenuItem: Locator;
  readonly nicklistContextMenu: Locator;
  readonly nicklistContextQueryMenuItem: Locator;
  readonly nicklistContextWhoisMenuItem: Locator;
  readonly nicklistContextIgnoreMenuItem: Locator;
  readonly nicklistContextUnignoreMenuItem: Locator;
  readonly nicklistContextP2PMenuItem: Locator;
  readonly nicklistContextCallMenuItem: Locator;
  readonly nicklistContextVideoCallMenuItem: Locator;
  readonly nicklistContextSendFileMenuItem: Locator;
  readonly nicklistContextGameMenuItem: Locator;
  readonly nicklistContextVoiceMenuItem: Locator;
  readonly nicklistContextOpMenuItem: Locator;
  readonly conversationsContextMenu: Locator;
  readonly conversationsMarkReadMenuItem: Locator;
  readonly conversationsMuteMenuItem: Locator;
  readonly conversationsCopyNameMenuItem: Locator;
  readonly conversationsSettingsMenuItem: Locator;
  readonly conversationsLeaveMenuItem: Locator;
  readonly conversationsSidebar: Locator;
  readonly replyBar: Locator;
  readonly replyBarDismissButton: Locator;
  readonly replyBlock: Locator;
  readonly typingIndicator: Locator;
  readonly deleteConfirmButton: Locator;
  readonly deleteCancelButton: Locator;
  readonly aboutDialog: Locator;
  readonly aboutOkButton: Locator;
  readonly cheatsheetDialog: Locator;
  readonly cheatsheetCloseButton: Locator;
  readonly helpContentPane: Locator;
  readonly notifyListDialog: Locator;
  readonly notifyAutoAddPmToggle: Locator;
  readonly notifyAutoWhoisToggle: Locator;
  readonly addressBookDialog: Locator;
  readonly nickColorsDialog: Locator;
  readonly ignoreListDialog: Locator;
  readonly channelListDialog: Locator;
  readonly channelCentralDialog: Locator;
  readonly aliasDialog: Locator;
  readonly aliasEditForm: Locator;
  readonly aliasWarning: Locator;
  readonly highlightDialog: Locator;
  readonly highlightAddForm: Locator;
  readonly highlightEditForm: Locator;
  readonly highlightWordInput: Locator;
  readonly floodProtectionDialog: Locator;
  readonly floodThresholdInput: Locator;
  readonly floodWindowInput: Locator;
  readonly floodAutoIgnoreDurationInput: Locator;
  readonly floodSaveButton: Locator;
  readonly floodResetDefaultsButton: Locator;
  readonly customMenusDialog: Locator;
  readonly customMenuEditForm: Locator;
  readonly urlCatcherDialog: Locator;
  readonly urlCatcherSearch: Locator;
  readonly urlCatcherRows: Locator;
  readonly performDialog: Locator;
  readonly autojoinDialog: Locator;
  readonly performAddDialog: Locator;
  readonly performEditDialog: Locator;
  readonly autojoinAddDialog: Locator;
  readonly autojoinEditDialog: Locator;
  readonly soundSettingsDialog: Locator;
  readonly autorespondDialog: Locator;
  readonly autorespondEditForm: Locator;
  readonly accountDialog: Locator;
  readonly profileDialog: Locator;
  readonly awayDialog: Locator;
  readonly userModesDialog: Locator;
  readonly accountPasswordInput: Locator;
  readonly accountConfirmInput: Locator;
  readonly accountDropPasswordInput: Locator;
  readonly accountNewNickInput: Locator;
  readonly accountBioInput: Locator;
  readonly accountAwayMessageInput: Locator;
  readonly accountGhostNicknameInput: Locator;
  readonly accountGhostPasswordInput: Locator;
  readonly timersDialog: Locator;
  readonly timersEditForm: Locator;
  readonly userLookupDialog: Locator;
  readonly lookupResultDialog: Locator;
  readonly lookupResultCard: Locator;
  readonly inviteChannelPickerDialog: Locator;
  readonly knockRequestDialog: Locator;
  readonly muteDurationDialog: Locator;
  readonly botManagementDialog: Locator;
  readonly adminChannelsWindow: Locator;
  readonly adminChannelsPanel: Locator;
  readonly adminChannelsInlineResult: Locator;
  readonly adminUsersWindow: Locator;
  readonly adminUsersPanel: Locator;
  readonly adminUsersInlineResult: Locator;
  readonly adminConsoleDialog: Locator;
  readonly adminConsoleInput: Locator;
  readonly adminConsoleOutput: Locator;
  readonly botList: Locator;
  readonly botManagementCloseButton: Locator;
  readonly newBotButton: Locator;
  readonly newBotDialog: Locator;
  readonly newBotNameInput: Locator;
  readonly newBotNicknameInput: Locator;
  readonly newBotDescriptionInput: Locator;
  readonly newBotCreateButton: Locator;
  readonly newBotCancelButton: Locator;
  readonly addCommandDialog: Locator;
  readonly nickChangeDialog: Locator;
  readonly nickChangePassword: Locator;
  readonly nickChangeConfirmButton: Locator;
  readonly nickChangeCancelButton: Locator;
  readonly nickChangeError: Locator;
  readonly channelListSearch: Locator;
  readonly channelListJoinButton: Locator;
  readonly channelListCloseButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.menuBar = page.getByTestId("menu-bar");
    this.chatInput = page.getByTestId("chat-input-field");
    this.chatSendButton = page.getByTestId("chat-input-send");
    this.charCounter = page.getByTestId("char-counter");
    this.appLogo = page.getByTestId("app-logo");
    this.statusBarApp = page.getByTestId("status-bar-app");
    this.statusBarMuteToggle = page.getByTestId("status-bar-mute-toggle");
    this.statusBarNotifyBadge = page.getByTestId("status-bar-notify-badge");
    this.connectionStatusHook = page.getByTestId("connection-status-hook");
    this.connectionBanner = this.connectionStatusHook.locator(
      '[data-role="banner"]',
    );
    this.reconnectOverlay = this.connectionStatusHook.locator(
      '[data-role="overlay"]',
    );
    this.reconnectOverlayAction = this.connectionStatusHook.locator(
      '[data-role="overlay-action"]',
    );
    this.messageList = page.getByTestId("chat-message-list");
    this.messageRows = this.messageList.locator("[data-message-id]");
    this.statusMessageList = page.getByTestId("status-messages");
    this.nicklist = page.getByTestId("nicklist");
    this.topicBar = page.getByTestId("topic-bar");
    this.tabBar = page.getByTestId("tab-bar");
    this.formattingToolbarToggle = page.getByTestId(
      "formatting-toolbar-toggle",
    );
    this.formattingToolbarPanel = page.getByTestId("formatting-toolbar-panel");
    this.formatBoldButton = page.getByTestId("format-btn-bold");
    this.formatItalicButton = page.getByTestId("format-btn-italic");
    this.formatUnderlineButton = page.getByTestId("format-btn-underline");
    this.formatColorButton = page.getByTestId("format-btn-color");
    this.formatReverseButton = page.getByTestId("format-btn-reverse");
    this.formatResetButton = page.getByTestId("format-btn-reset");
    this.stripFormattingToggle = page.getByTestId("strip-formatting-toggle");
    this.emojiPickerToggle = page.getByTestId("emoji-picker-toggle");
    this.emojiPicker = page.getByTestId("emoji-picker");
    this.emojiPickerSearch = page.getByTestId("emoji-picker-search");
    this.autocompleteDropdown = page.getByTestId("autocomplete-dropdown");
    // menu_bar_app renders one <button data-menubar-trigger> per top-level
    // label; we filter by visible label text rather than rely on order.
    this.fileMenuTrigger = page
      .locator("button[data-menubar-trigger]")
      .filter({ hasText: "File" });
    this.editMenuTrigger = page
      .locator("button[data-menubar-trigger]")
      .filter({ hasText: "Edit" });
    this.viewMenuTrigger = page
      .locator("button[data-menubar-trigger]")
      .filter({ hasText: "View" });
    this.helpMenuTrigger = page
      .locator("button[data-menubar-trigger]")
      .filter({ hasText: "Help" });
    this.toolsMenuTrigger = page
      .locator("button[data-menubar-trigger]")
      .filter({ hasText: "Tools" });
    this.gamesMenuTrigger = page
      .locator("button[data-menubar-trigger]")
      .filter({ hasText: "Games" });
    this.arcadeMenuItem = visibleContextMenuItem(page, "open_arcade");
    this.arcadeWindow = page.getByTestId("arcade-games-window");
    // context_menu_item exposes data-testid="context-menu-item-<action>".
    this.disconnectMenuItem = visibleContextMenuItem(page, "disconnect");
    this.adminSubmenuTrigger = page
      .getByTestId("app-menu-admin-submenu")
      .locator("visible=true");
    this.adminConsoleMenuItem = visibleContextMenuItem(
      page,
      "open_admin_console",
    );
    this.adminUsersMenuItem = visibleContextMenuItem(page, "open_admin_users");
    this.adminChannelsMenuItem = visibleContextMenuItem(
      page,
      "open_admin_channels",
    );
    this.accountRegisterMenuItem = visibleContextMenuItem(
      page,
      "open_account_register",
    );
    this.accountIdentifyMenuItem = visibleContextMenuItem(
      page,
      "open_account_identify",
    );
    // "Change Nickname..." and "Edit Profile..." are two File-menu items with
    // the same action — a pre-existing duplication that the split inherited.
    this.accountProfileMenuItem = visibleContextMenuItem(
      page,
      "open_profile_dialog",
    ).first();
    this.accountAwayMenuItem = visibleContextMenuItem(page, "open_away_dialog");
    this.accountUserModesMenuItem = visibleContextMenuItem(
      page,
      "open_user_modes_dialog",
    );
    this.accountInfoMenuItem = visibleContextMenuItem(page, "account_info");
    this.clearWindowMenuItem = visibleContextMenuItem(page, "clear_window");
    this.copySelectionMenuItem = visibleContextMenuItem(page, "copy_selection");
    this.channelListMenuItem = visibleContextMenuItem(
      page,
      "toggle_channel_list",
    );
    this.toggleConversationsMenuItem = visibleContextMenuItem(
      page,
      "toggle_conversations",
    );
    this.toggleNicklistMenuItem = visibleContextMenuItem(
      page,
      "toggle_nicklist",
    );
    this.notifyListMenuItem = visibleContextMenuItem(
      page,
      "toggle_notify_list",
    );
    this.findMenuItem = visibleContextMenuItem(page, "toggle_search");
    this.helpTopicsMenuItem = visibleContextMenuItem(page, "help_topics");
    this.cheatsheetMenuItem = visibleContextMenuItem(page, "toggle_cheatsheet");
    this.aboutMenuItem = visibleContextMenuItem(page, "show_about");
    this.nickColorsMenuItem = visibleContextMenuItem(
      page,
      "open_nick_colors_dialog",
    );
    this.ignoreListMenuItem = visibleContextMenuItem(
      page,
      "open_ignore_list_dialog",
    );
    this.addressBookMenuItem = visibleContextMenuItem(
      page,
      "toggle_address_book",
    );
    this.highlightWordsMenuItem = visibleContextMenuItem(
      page,
      "open_highlight_dialog",
    );
    this.channelCentralMenuItem = visibleContextMenuItem(
      page,
      "open_channel_central",
    );
    this.performMenuItem = visibleContextMenuItem(page, "open_perform_dialog");
    this.autojoinMenuItem = visibleContextMenuItem(
      page,
      "open_autojoin_dialog",
    );
    this.soundSettingsMenuItem = visibleContextMenuItem(
      page,
      "open_sound_settings_dialog",
    );
    this.aliasEditorMenuItem = visibleContextMenuItem(
      page,
      "open_alias_dialog",
    );
    this.floodProtectionMenuItem = visibleContextMenuItem(
      page,
      "open_flood_protection_dialog",
    );
    this.customMenusMenuItem = visibleContextMenuItem(
      page,
      "open_custom_menus_dialog",
    );
    this.autorespondMenuItem = visibleContextMenuItem(
      page,
      "open_autorespond_dialog",
    );
    this.timersMenuItem = visibleContextMenuItem(page, "open_timers_dialog");
    this.urlCatcherMenuItem = visibleContextMenuItem(
      page,
      "toggle_url_catcher",
    );
    this.userLookupMenuItem = visibleContextMenuItem(page, "open_user_lookup");
    this.botManagementMenuItem = visibleContextMenuItem(
      page,
      "open_bot_dialog",
    );
    this.messageOfTheDayMenuItem = visibleContextMenuItem(page, "show_motd");
    this.inlineHelp = page.getByTestId("inline-help");
    this.syntaxTooltip = page.getByTestId("syntax-tooltip");
    this.historySearch = page.getByTestId("history-search");
    this.historySearchInput = page.getByTestId("history-search-input");
    this.historySearchNoResults = page.getByTestId("history-search-no-results");
    this.searchBar = page.getByTestId("search-bar");
    this.searchBarInput = page.getByTestId("search-bar-input");
    this.searchBarCount = page.getByTestId("search-bar-count");
    this.searchBarPrevButton = page.getByTestId("search-bar-prev");
    this.searchBarNextButton = page.getByTestId("search-bar-next");
    this.searchBarCaseSensitive = page.getByTestId("search-bar-case-sensitive");
    this.searchBarRegex = page.getByTestId("search-bar-regex");
    this.searchBarMyMentions = page.getByTestId("search-bar-my-mentions");
    this.searchBarHistory = page.getByTestId("search-bar-history");
    this.searchHighlights = page.locator("mark.search-highlight");
    this.searchActiveHighlight = page.locator("mark.search-highlight-active");
    this.pasteConfirmDialog = page.getByTestId("paste-confirm-dialog");
    this.pasteConfirmSendButton = page.getByTestId("paste-confirm-send");
    this.pasteConfirmCancelButton = page.getByTestId("paste-confirm-cancel");
    this.pasteFloodWarning = page.getByTestId("paste-flood-warning");
    this.chatContextMenu = page.getByTestId("context-menu-chat-context-menu");
    this.contextCopyMessageMenuItem = page.getByTestId(
      "context-menu-item-ctx_chat_copy_message",
    );
    this.contextReplyMenuItem = page.getByTestId(
      "context-menu-item-reply_to_message",
    );
    this.contextEditMenuItem = page.getByTestId(
      "context-menu-item-edit_message",
    );
    this.contextDeleteMenuItem = page.getByTestId(
      "context-menu-item-ctx_chat_delete",
    );
    this.chatContextCallMenuItem = page.getByTestId(
      "context-menu-item-ctx_chat_call",
    );
    this.chatContextVideoCallMenuItem = page.getByTestId(
      "context-menu-item-ctx_chat_video_call",
    );
    this.chatContextSendFileMenuItem = page.getByTestId(
      "context-menu-item-ctx_chat_sendfile",
    );
    this.chatContextGameMenuItem = page.getByTestId(
      "context-menu-item-ctx_chat_game",
    );
    this.nicklistContextMenu = page.getByTestId(
      "context-menu-nicklist-context-menu",
    );
    this.nicklistContextQueryMenuItem = page.getByTestId(
      "context-menu-item-context_query",
    );
    this.nicklistContextWhoisMenuItem = page.getByTestId(
      "context-menu-item-context_whois",
    );
    this.nicklistContextIgnoreMenuItem = page.getByTestId(
      "context-menu-item-context_ignore",
    );
    this.nicklistContextUnignoreMenuItem = page.getByTestId(
      "context-menu-item-context_unignore",
    );
    this.nicklistContextP2PMenuItem = page.getByTestId(
      "context-menu-item-context_p2p",
    );
    this.nicklistContextCallMenuItem = page.getByTestId(
      "context-menu-item-context_call",
    );
    this.nicklistContextVideoCallMenuItem = page.getByTestId(
      "context-menu-item-context_video_call",
    );
    this.nicklistContextSendFileMenuItem = page.getByTestId(
      "context-menu-item-context_sendfile",
    );
    this.nicklistContextGameMenuItem = page.getByTestId(
      "context-menu-item-context_game",
    );
    this.nicklistContextVoiceMenuItem = page.getByTestId(
      "context-menu-item-context_voice",
    );
    this.nicklistContextOpMenuItem = page.getByTestId(
      "context-menu-item-context_op",
    );
    this.conversationsContextMenu = page.getByTestId(
      "context-menu-conversations-context-menu",
    );
    this.conversationsMarkReadMenuItem = page
      .locator(
        '[data-testid="ctx-mark-read"], [data-testid="context-menu-item-ctx_conversations_mark_read"]',
      )
      .first();
    this.conversationsMuteMenuItem = page
      .locator(
        '[data-testid="ctx-mute-toggle"], [data-testid="context-menu-item-ctx_conversations_mute"]',
      )
      .first();
    this.conversationsCopyNameMenuItem = page
      .locator(
        '[data-testid="ctx-copy-name"], [data-testid="context-menu-item-ctx_conversations_copy_name"]',
      )
      .first();
    this.conversationsSettingsMenuItem = page
      .locator(
        '[data-testid="ctx-channel-settings"], [data-testid="context-menu-item-ctx_conversations_settings"]',
      )
      .first();
    this.conversationsLeaveMenuItem = page
      .locator(
        '[data-testid="ctx-leave"], [data-testid="context-menu-item-ctx_conversations_leave"]',
      )
      .first();
    this.conversationsSidebar = page.getByTestId("conversations");
    this.replyBar = page.getByTestId("reply-bar");
    this.replyBarDismissButton = page.getByTestId("reply-bar-dismiss");
    this.replyBlock = page.getByTestId("reply-block");
    this.typingIndicator = page.getByTestId("typing-indicator");
    this.deleteConfirmButton = page.getByTestId(
      "delete-confirm-dialog-confirm",
    );
    this.deleteCancelButton = page.getByTestId("delete-confirm-dialog-cancel");
    this.aboutDialog = page.locator('#about-dialog [role="dialog"]');
    this.aboutOkButton = this.aboutDialog.getByRole("button", { name: "OK" });
    this.cheatsheetDialog = page.getByTestId("cheatsheet-window");
    this.cheatsheetCloseButton = page
      .getByTestId("cheatsheet-window")
      .locator('[data-window-control="close"]');
    this.helpContentPane = page.getByTestId("help-content-pane");
    this.notifyListDialog = page.getByTestId("notify-list-window");
    this.notifyAutoAddPmToggle = page.locator(
      "#notify-list-dialog-auto-add-pm",
    );
    this.notifyAutoWhoisToggle = page.locator("#notify-list-dialog-auto-whois");
    this.addressBookDialog = page.getByTestId("address-book-window");
    this.nickColorsDialog = page.getByTestId("nick-colors-window");
    this.ignoreListDialog = page.getByTestId("ignore-list-window");
    this.channelListDialog = page.getByTestId("channel-list-window");
    this.channelCentralDialog = page.getByTestId("channel-central-window");
    this.aliasDialog = page.getByTestId("alias-window");
    this.aliasEditForm = page.getByTestId("alias-edit-form");
    this.aliasWarning = page.getByTestId("alias-warning");
    this.highlightDialog = page.getByTestId("highlight-window");
    this.highlightAddForm = page.getByTestId("highlight-add-form");
    this.highlightEditForm = page.getByTestId("highlight-edit-form");
    this.highlightWordInput = page.locator("#highlight-word-input");
    this.floodProtectionDialog = page.getByTestId("flood-protection-window");
    this.floodThresholdInput = this.floodProtectionDialog.locator(
      'input[name="flood_threshold"]',
    );
    this.floodWindowInput = this.floodProtectionDialog.locator(
      'input[name="flood_window_seconds"]',
    );
    this.floodAutoIgnoreDurationInput = this.floodProtectionDialog.locator(
      'input[name="auto_ignore_duration_seconds"]',
    );
    this.floodSaveButton = this.floodProtectionDialog.getByRole("button", {
      name: "Save",
    });
    this.floodResetDefaultsButton = this.floodProtectionDialog.getByRole(
      "button",
      { name: "Reset Defaults" },
    );
    this.customMenusDialog = page.getByTestId("custom-menus-window");
    this.customMenuEditForm = page.getByTestId("custom-menu-edit-form");
    this.urlCatcherDialog = page.getByTestId("url-catcher-window");
    this.urlCatcherSearch = page.getByTestId("url-catcher-search");
    this.urlCatcherRows = this.urlCatcherDialog.getByTestId("url-catcher-row");
    this.performDialog = page.getByTestId("perform-window");
    this.autojoinDialog = page.getByTestId("autojoin-window");
    this.performAddDialog = page.getByTestId("perform-add-dialog");
    this.performEditDialog = page.getByTestId("perform-edit-dialog");
    this.autojoinAddDialog = page.getByTestId("autojoin-add-dialog");
    this.autojoinEditDialog = page.getByTestId("autojoin-edit-dialog");
    this.soundSettingsDialog = page.getByTestId("sound-settings-window");
    this.autorespondDialog = page.getByTestId("auto-respond-window");
    this.autorespondEditForm = this.autorespondDialog.locator("form");
    this.accountDialog = page.getByTestId("account-window");
    this.profileDialog = page.getByTestId("profile-window");
    this.awayDialog = page.getByTestId("away-window");
    this.userModesDialog = page.getByTestId("user-modes-window");
    this.accountPasswordInput = page.getByTestId("account-password");
    this.accountConfirmInput = page.getByTestId("account-confirm");
    this.accountDropPasswordInput = page.getByTestId("account-drop-password");
    this.accountNewNickInput = page.getByTestId("account-new-nick");
    this.accountBioInput = page.getByTestId("profile-bio");
    this.accountAwayMessageInput = page.getByTestId("away-message");
    this.accountGhostNicknameInput = page.getByTestId("account-ghost-nickname");
    this.accountGhostPasswordInput = page.getByTestId("account-ghost-password");
    this.timersDialog = page.getByTestId("timers-window");
    this.timersEditForm = page.getByTestId("timers-edit-form");
    this.userLookupDialog = page.getByTestId("user-lookup-window");
    // The result card renders inside the user-lookup window, title included.
    this.lookupResultDialog = page.getByTestId("lookup-result-card");
    this.lookupResultCard = page.getByTestId("lookup-result-card");
    this.inviteChannelPickerDialog = page.locator(
      '#invite-channel-picker-dialog [role="dialog"]',
    );
    this.knockRequestDialog = page.locator(
      '#knock-request-dialog [role="dialog"]',
    );
    this.muteDurationDialog = page.locator(
      '#mute-duration-dialog [role="dialog"]',
    );
    this.botManagementDialog = page.locator(
      '[data-testid="bot-management-window"]',
    );
    this.adminConsoleDialog = page.locator(
      '[data-testid="admin-console-window"]',
    );
    this.adminChannelsWindow = page.getByTestId("admin-channels-window");
    this.adminChannelsPanel = page.getByTestId("admin-channels-panel");
    this.adminChannelsInlineResult = this.adminChannelsPanel.getByTestId(
      "admin-inline-result",
    );
    this.adminUsersWindow = page.getByTestId("admin-users-window");
    this.adminUsersPanel = page.getByTestId("admin-users-panel");
    this.adminUsersInlineResult = this.adminUsersPanel.getByTestId(
      "admin-inline-result",
    );
    this.adminConsoleInput = page.locator("#admin-console-input");
    this.adminConsoleOutput = page.getByTestId("admin-console-output");
    this.botList = page.getByTestId("bot-list");
    this.botManagementCloseButton = this.botManagementDialog.locator(
      '[data-window-control="close"]',
    );
    this.newBotButton = this.botManagementDialog.getByRole("button", {
      name: "New",
    });
    this.newBotDialog = page.locator('#new-bot-dialog [role="dialog"]');
    this.newBotNameInput = page.locator("#bot-name");
    this.newBotNicknameInput = page.locator("#bot-nickname");
    this.newBotDescriptionInput = page.locator("#bot-description");
    this.newBotCreateButton = this.newBotDialog.getByRole("button", {
      name: "Create",
    });
    this.newBotCancelButton = this.newBotDialog.getByRole("button", {
      name: "Cancel",
    });
    this.addCommandDialog = page.locator('#add-command-dialog [role="dialog"]');
    this.nickChangeDialog = page.getByTestId("nick-change-dialog");
    this.nickChangePassword = page.getByTestId("nick-change-password");
    this.nickChangeConfirmButton = page.getByTestId("nick-change-confirm");
    this.nickChangeCancelButton = page.getByTestId("nick-change-cancel");
    this.nickChangeError = page.getByTestId("nick-change-error");
    this.channelListSearch = page.getByTestId("channel-list-search");
    this.channelListJoinButton = page.getByTestId("channel-list-join");
    this.channelListCloseButton = page
      .getByTestId("channel-list-window")
      .locator('[data-window-control="close"]');
    // The dialog component wraps content in a <span data-testid="...">, but
    // that wrapper has zero visible size when the dialog is closed; use the
    // confirm button instead as the open/closed signal.
    this.disconnectConfirmDialog = page.getByTestId(
      "disconnect-confirm-dialog-confirm",
    );
    this.disconnectConfirmButton = page.getByTestId(
      "disconnect-confirm-dialog-confirm",
    );
    this.kickDialogOkButton = page.getByTestId("kick-dialog-ok");
  }

  // Waits until we are at /chat AND the LiveView socket is connected
  // (the File menu trigger is enabled and MenuBarHook has mounted).
  // The MenuBarHook is what makes clicking File open the dropdown — without
  // it the click is a no-op, so we wait for a phx-hook root with the live
  // session attribute to confirm hooks have wired up.
  async waitUntilConnected() {
    await expect(this.page).toHaveURL(/\/chat(\?.*)?$/);
    await expect(this.menuBar).toBeVisible();
    await expect(
      this.page.locator("button[data-menubar-trigger]").first(),
    ).toBeEnabled();
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
    const statusTab = this.page.getByRole("tab", { name: "Status" });
    await statusTab.click();
    await expect(statusTab).toHaveAttribute("aria-selected", "true");
    await expect(this.statusMessageList).toBeVisible();
    await expect(this.messageList).toBeHidden();
  }

  // Returns the tab element with the given visible label (e.g. "#lobby").
  // Names with leading "#" need no special escaping here — Playwright's
  // accessible-name match works literally.
  tab(name: string): Locator {
    return this.page.getByRole("tab", { name, exact: false });
  }

  async switchToTab(name: string) {
    const targetTab = this.tab(name);
    await targetTab.click();
    await expect(targetTab).toHaveAttribute("aria-selected", "true");
    await expect(this.chatInput).toHaveAttribute(
      "placeholder",
      new RegExp(escapeRegExp(name)),
    );
  }

  // Each tab contains a nested "Close tab" button.
  async closeTab(name: string) {
    await this.tab(name).getByRole("button", { name: "Close tab" }).click();
  }

  async openSearchFromEditMenu() {
    await this.editMenuTrigger.click();
    await expect(this.findMenuItem).toBeVisible();
    await this.findMenuItem.click();
    await expect(this.searchBar).toBeVisible();
  }

  async openArcadeFromGamesMenu() {
    await this.gamesMenuTrigger.click();
    await expect(this.arcadeMenuItem).toBeVisible();
    await this.arcadeMenuItem.click();
    await expect(this.arcadeWindow).toBeVisible();
  }

  async openNotifyListFromViewMenu() {
    await this.viewMenuTrigger.click();
    await expect(this.notifyListMenuItem).toBeVisible();
    await this.notifyListMenuItem.click();
    await expect(this.notifyListDialog).toBeVisible();
  }

  async openFloodProtectionFromToolsMenu() {
    await this.openToolsMenuItem(this.floodProtectionMenuItem);
    await this.floodProtectionMenuItem.click();
    await expect(this.floodThresholdInput).toBeVisible();
  }

  async expectTabVisible(name: string) {
    await expect(this.tab(name)).toBeVisible();
  }

  async expectTabSelected(name: string) {
    await expect(this.tab(name)).toHaveAttribute("aria-selected", "true");
  }

  async expectTabHidden(name: string) {
    await expect(this.tab(name)).toHaveCount(0);
  }

  async expectTabUnread(name: string, unread: boolean) {
    await expect(this.tab(name)).toHaveAttribute("data-unread", String(unread));
  }

  // Types a message (or slash command) into the chat input and submits
  // by pressing Enter. The form's phx-submit handler dispatches commands
  // through the same path real users hit when typing `/...`.
  async sendMessage(text: string) {
    await expect(this.chatInput).toBeEnabled();
    await this.chatInput.fill(text);
    await expect(this.chatSendButton).toBeEnabled();
    await this.chatInput.press("Enter");

    if (!text.startsWith("/")) {
      await expect(this.chatInput).toHaveValue("");
    }
  }

  async pasteText(text: string) {
    await expect(this.chatInput).toBeEnabled();
    await this.chatInput.focus();

    const dispatch = () =>
      this.chatInput.evaluate((el, pasted) => {
        const clipboard = new DataTransfer();
        clipboard.setData("text/plain", pasted);
        const event = new ClipboardEvent("paste", {
          bubbles: true,
          cancelable: true,
          clipboardData: clipboard,
        });
        el.dispatchEvent(event);
      }, text);

    // The first paste right after connect can be swallowed by the LiveView
    // join-render burst (the documented connect-burst race) — the PasteHook
    // listener / pushEvent is lost and the confirm dialog never opens. Re-dispatch
    // until the confirm dialog appears. All callers paste 2+ lines, which always
    // opens the dialog, so waiting for it here is safe.
    await expect(async () => {
      await dispatch();
      await expect(this.pasteConfirmSendButton).toBeVisible({ timeout: 1_000 });
    }).toPass({ timeout: 10_000 });
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
    await expect(
      this.messageList.getByText(text, { exact: false }),
    ).toHaveCount(0);
  }

  async expectMessageNotVisible(text: string) {
    await expect(
      this.messageList.getByText(text, { exact: false }).first(),
    ).toBeHidden();
  }

  messageRowByText(text: string): Locator {
    return this.messageRows.filter({ hasText: text }).first();
  }

  messageTimestampByText(text: string): Locator {
    return this.messageRowByText(text)
      .getByTestId("chat-message-timestamp")
      .first();
  }

  messageNickByText(text: string, nick: string): Locator {
    return this.messageRowByText(text).locator(`[data-nick="${nick}"]`).first();
  }

  async openMessageContextMenu(text: string) {
    await this.messageRowByText(text).click({ button: "right" });
    await expect(this.chatContextMenu).toBeVisible();
  }

  async openChatNickContextMenu(text: string, nick: string) {
    await this.messageNickByText(text, nick).click({ button: "right" });
    await expect(this.chatContextMenu).toBeVisible();
  }

  async expectActiveMessageCount(count: number) {
    await expect(
      this.messageList.locator("[data-message-id]:visible"),
    ).toHaveCount(count);
  }

  async scrollMessagesToTop() {
    await this.messageList.evaluate((el) => {
      el.dispatchEvent(
        new WheelEvent("wheel", {
          bubbles: true,
          cancelable: true,
          deltaY: -1000,
        }),
      );
      el.scrollTop = 0;
      el.dispatchEvent(new Event("scroll", { bubbles: true }));
    });
  }

  async scrollMessagesToBottom() {
    await this.messageList.evaluate((el) => {
      el.scrollTop = el.scrollHeight;
      el.dispatchEvent(new Event("scroll", { bubbles: true }));
    });
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
    role: "owner" | "operator" | "half_operator" | "voiced" | "regular",
  ) {
    await expect(this.nicklistItem(nick)).toHaveAttribute("data-role", role);
  }

  async expectNickStatus(nick: string, status: "online" | "away" | "offline") {
    await expect(this.nicklistItem(nick)).toHaveAttribute(
      "data-status",
      status,
    );
  }

  async openNickHoverCard(nick: string) {
    await this.nicklistItem(nick).hover();
    await expect(this.hoverCard(nick)).toBeVisible();
  }

  async openNicklistContextMenu(nick: string) {
    await this.nicklistItem(nick).click({ button: "right" });
    await expect(this.nicklistContextMenu).toBeVisible();
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

  addressBookContactRow(nick: string): Locator {
    return this.page.locator(`[id="contact-entry-${nick}"]`);
  }

  addressBookNickColorRow(nick: string): Locator {
    return this.page.locator(`[id="nick-color-entry-${nick}"]`);
  }

  addressBookControlRow(nick: string): Locator {
    return this.page.locator(`[id="control-entry-${nick}"]`);
  }

  aliasRow(name: string): Locator {
    return this.aliasDialog
      .getByTestId("alias-row")
      .filter({ hasText: `/${name}` })
      .first();
  }

  customMenuPanel(tab: "Nicklist" | "Channel" | "Chat"): Locator {
    const value = tab.toLowerCase();
    return this.customMenusDialog.locator(`.tabs-content[value="${value}"]`);
  }

  customMenuRow(label: string): Locator {
    return this.customMenusDialog
      .getByTestId("custom-menu-row")
      .filter({ hasText: label })
      .first();
  }

  customMenuRowInTab(
    tab: "Nicklist" | "Channel" | "Chat",
    label: string,
  ): Locator {
    return this.customMenuPanel(tab)
      .getByTestId("custom-menu-row")
      .filter({ hasText: label })
      .first();
  }

  urlCatcherRowByUrl(url: string): Locator {
    return this.urlCatcherRows.filter({ hasText: url }).first();
  }

  botItem(name: string): Locator {
    return this.page.getByTestId(`bot-item-${name}`);
  }

  arcadeSessionLink(): Locator {
    return this.messageList.getByRole("link", { name: "Open Arcade" }).first();
  }

  p2pInviteCard(): Locator {
    return this.messageList.getByTestId("session-card").last();
  }

  emojiButton(char: string): Locator {
    return this.emojiPicker.getByRole("button", { name: char });
  }

  async openFormattingToolbar() {
    if (await this.formattingToolbarPanel.isVisible()) return;

    await this.formattingToolbarToggle.click();
    await expect(this.formattingToolbarPanel).toBeVisible();
  }

  /**
   * Opens the emoji picker from inside the compact formatting toolbar.
   *
   * `waitUntilConnected()` only waits for the WebSocket handshake
   * (`liveSocket.isConnected()`), which resolves before the initial join-render
   * has fully settled. A toggle click in that window can be swallowed by the
   * connect render burst, so we retry once if the picker doesn't appear.
   */
  async openEmojiPicker() {
    await this.openFormattingToolbar();
    await this.emojiPickerToggle.click();
    try {
      await expect(this.emojiPicker).toBeVisible({ timeout: 2_000 });
    } catch {
      await this.openFormattingToolbar();
      await this.emojiPickerToggle.click();
      await expect(this.emojiPicker).toBeVisible({ timeout: 5_000 });
    }
  }

  formatColorSwatch(index: number): Locator {
    return this.page.getByTestId(`format-color-swatch-${index}`);
  }

  customContextMenuItem(label: string): Locator {
    return this.page
      .getByTestId("context-menu-item-custom_menu_execute")
      .filter({ hasText: label })
      .first();
  }

  customNicklistContextMenuItem(label: string): Locator {
    return this.nicklistContextMenu
      .getByTestId("context-menu-item-custom_menu_execute")
      .filter({ hasText: label })
      .first();
  }

  customConversationContextMenuItem(label: string): Locator {
    return this.conversationsContextMenu
      .getByTestId("context-menu-item-custom_menu_execute")
      .filter({ hasText: label })
      .first();
  }

  customChatContextMenuItem(label: string): Locator {
    return this.chatContextMenu
      .getByTestId("context-menu-item-custom_menu_execute")
      .filter({ hasText: label })
      .first();
  }

  channelCentralPanel(tab: ChannelCentralTab): Locator {
    return this.channelCentralDialog.locator(`.tabs-content[value="${tab}"]`);
  }

  channelCentralEntry(nick: string): Locator {
    return this.channelCentralPanel("access_lists")
      .locator("tbody tr")
      .filter({ hasText: nick })
      .first();
  }

  channelConversationItem(channel: string): Locator {
    return this.page.getByTestId(`channel-${channel}`);
  }

  popularChannelItem(channel: string): Locator {
    return this.page.getByTestId(`popular-${channel}`);
  }

  popularJoinButton(channel: string): Locator {
    return this.page.getByTestId(`join-${channel}`);
  }

  conversationSection(section: "channels" | "pms" | "popular"): Locator {
    return this.page.getByTestId(`conversations-section-${section}`);
  }

  conversationSectionTrigger(section: "channels" | "pms" | "popular"): Locator {
    return this.conversationSection(section).locator("button").first();
  }

  pmConversationItem(nick: string): Locator {
    return this.page.getByTestId(`pm-${nick}`);
  }

  hoverCard(nick: string): Locator {
    return this.page.getByTestId(`hover-card-${nick}`);
  }

  channelUnreadBadge(channel: string): Locator {
    return this.page.getByTestId(`channel-unread-badge-${channel}`);
  }

  pmUnreadBadge(nick: string): Locator {
    return this.page.getByTestId(`pm-unread-badge-${nick}`);
  }

  async openConversationContextMenu(channel: string) {
    await this.channelConversationItem(channel).click({ button: "right" });
    await expect(this.conversationsContextMenu).toBeVisible();
  }

  async openPmConversationContextMenu(nick: string) {
    await this.pmConversationItem(nick).click({ button: "right" });
    await expect(this.conversationsContextMenu).toBeVisible();
  }

  async toggleConversationSection(section: "channels" | "pms" | "popular") {
    await this.conversationSectionTrigger(section).click();
  }

  async expandConversationSection(section: "channels" | "pms" | "popular") {
    const expanded =
      (await this.conversationSectionTrigger(section).getAttribute(
        "aria-expanded",
      )) === "true";

    if (!expanded) {
      await this.toggleConversationSection(section);
    }

    await this.expectConversationSectionExpanded(section, true);
  }

  async expectConversationSectionExpanded(
    section: "channels" | "pms" | "popular",
    expanded: boolean,
  ) {
    await expect(this.conversationSectionTrigger(section)).toHaveAttribute(
      "aria-expanded",
      String(expanded),
    );
  }

  async expectChannelConversationUnread(channel: string, unread: boolean) {
    await expect(this.channelConversationItem(channel)).toHaveAttribute(
      "data-unread",
      String(unread),
    );
  }

  async expectChannelConversationMuted(channel: string, muted: boolean) {
    await expect(this.channelConversationItem(channel)).toHaveAttribute(
      "data-muted",
      String(muted),
    );
  }

  async expectPmConversationUnread(nick: string, unread: boolean) {
    await expect(this.pmConversationItem(nick)).toHaveAttribute(
      "data-unread",
      String(unread),
    );
  }

  async expectPmConversationMuted(nick: string, muted: boolean) {
    await expect(this.pmConversationItem(nick)).toHaveAttribute(
      "data-muted",
      String(muted),
    );
  }

  async joinPopularChannel(channel: string) {
    await this.expandConversationSection("popular");
    await expect(this.popularChannelItem(channel)).toBeVisible();
    await this.popularJoinButton(channel).click();
    await this.expectTabVisible(channel);
    await this.expectTabSelected(channel);
  }

  async browseAllChannelsFromConversations() {
    await this.expandConversationSection("popular");
    await this.page.getByTestId("conversations-browse-all").click();
    await expect(this.channelListDialog).toBeVisible();
  }

  async closeChannelList() {
    await this.channelListCloseButton.click();
    await expect(this.channelListDialog).toBeHidden();
  }

  async openFileMenu() {
    // MenuBarHook listens for mousedown (not click) so that focus never
    // leaves the chat input. Playwright's click() does fire mousedown as
    // part of the click sequence, so a normal click is sufficient — but
    // we DO need the hook to be mounted first (see waitUntilConnected).
    await this.fileMenuTrigger.click();
    await expect(this.disconnectMenuItem).toBeVisible();
  }

  // The admin windows live behind File > Admin, so every opener expands the
  // submenu first.
  async openAdminSubmenu() {
    await this.openFileMenu();
    await expect(this.adminSubmenuTrigger).toBeVisible();
    await this.adminSubmenuTrigger.click();
  }

  async openAdminConsoleFromMenu() {
    await this.openAdminSubmenu();
    await expect(this.adminConsoleMenuItem).toBeVisible();
    await this.adminConsoleMenuItem.click();
    await expect(this.adminConsoleDialog).toBeVisible();
  }

  async openAdminUsersFromMenu() {
    await this.openAdminSubmenu();
    await expect(this.adminUsersMenuItem).toBeVisible();
    await this.adminUsersMenuItem.click();
    await expect(this.adminUsersWindow).toBeVisible();
  }

  async openAdminChannelsFromMenu() {
    await this.openAdminSubmenu();
    await expect(this.adminChannelsMenuItem).toBeVisible();
    await this.adminChannelsMenuItem.click();
    await expect(this.adminChannelsWindow).toBeVisible();
  }

  /**
   * Open any admin window by its opener action, e.g. "open_admin_motd".
   * The focused windows are alike enough that one helper covers them all.
   */
  async openAdminWindow(action: string) {
    const windowId = action.replace(/^open_/, "").replaceAll("_", "-");
    await this.openAdminSubmenu();
    const item = visibleContextMenuItem(this.page, action);
    await expect(item).toBeVisible();
    await item.click();
    await expect(this.page.getByTestId(`${windowId}-window`)).toBeVisible();
    return this.page.getByTestId(`${windowId}-panel`);
  }

  adminWindowResult(windowId: string) {
    return this.page
      .getByTestId(`${windowId}-panel`)
      .getByTestId("admin-inline-result");
  }

  async closeAdminWindow(windowId: string) {
    await this.page
      .locator(`[data-window-id="${windowId}"] [data-window-control="close"]`)
      .click();
  }

  async openAccountRegisterFromMenu() {
    await this.openFileMenu();
    await expect(this.accountRegisterMenuItem).toBeVisible();
    await this.accountRegisterMenuItem.click();
    await expect(this.accountDialog).toBeVisible();
  }

  async openAccountProfileFromMenu() {
    await this.openFileMenu();
    await expect(this.accountProfileMenuItem).toBeVisible();
    await this.accountProfileMenuItem.click();
    await expect(this.profileDialog).toBeVisible();
  }

  async openAwayFromMenu() {
    await this.openFileMenu();
    await expect(this.accountAwayMenuItem).toBeVisible();
    await this.accountAwayMenuItem.click();
    await expect(this.awayDialog).toBeVisible();
  }

  async openUserModesFromMenu() {
    await this.openFileMenu();
    await expect(this.accountUserModesMenuItem).toBeVisible();
    await this.accountUserModesMenuItem.click();
    await expect(this.userModesDialog).toBeVisible();
  }

  async openNewBotDialog() {
    await expect(this.botManagementDialog).toBeVisible();
    await this.newBotButton.click();
    await expect(this.newBotDialog).toBeVisible();
  }

  async closeBotManagementDialog() {
    if (!(await this.botManagementDialog.isVisible().catch(() => false))) {
      return;
    }

    await this.botManagementCloseButton.click();
    await expect(this.botManagementDialog).toBeHidden();
  }

  async openHelpTopicsFromMenu() {
    await this.helpMenuTrigger.click();
    await expect(this.helpTopicsMenuItem).toBeVisible();
    await this.helpTopicsMenuItem.click();
    await expect(this.page).toHaveURL(/\/chat\/help(\?.*)?$/);
    await expect(this.helpContentPane).toBeVisible();
  }

  async openMessageOfTheDayFromHelpMenu() {
    await this.helpMenuTrigger.click();
    await expect(this.messageOfTheDayMenuItem).toBeVisible();
    await this.messageOfTheDayMenuItem.click();
  }

  async openChannelCentralFromMenu() {
    await this.openToolsMenuItem(this.channelCentralMenuItem);
    await this.channelCentralMenuItem.click();
    await expect(this.channelCentralDialog).toBeVisible();
  }

  async switchChannelCentralToTab(tab: ChannelCentralTab) {
    await this.channelCentralDialog
      .locator(`button[data-target="${tab}"], button[phx-value-tab="${tab}"]`)
      .click();
    await expect(this.channelCentralPanel(tab)).toBeVisible();
  }

  async openUserLookupFromToolsMenu() {
    await this.openToolsMenuItem(this.userLookupMenuItem);
    await this.userLookupMenuItem.click();
    await expect(this.userLookupDialog).toBeVisible();
  }

  // A typed /whois (and the nicklist/chat "Whois" context-menu item) renders a
  // structured result card titled "Whois: <nick>".
  async expectWhoisCard(nick: string) {
    await expect(this.lookupResultCard).toBeVisible();
    await expect(this.lookupResultDialog).toContainText(`Whois: ${nick}`);
  }

  // Asserts a "<label>: <value>" row inside the visible lookup result card.
  // The label is matched exactly so "Channels" does not also match "Shared channels".
  async expectLookupCardField(label: string, value: string) {
    const row = this.lookupResultCard.locator("div", {
      has: this.page.locator("dt", { hasText: new RegExp(`^${label}:$`) }),
    });
    await expect(row).toContainText(value);
  }

  async expectLookupCardMissingField(label: string) {
    await expect(
      this.lookupResultCard.locator("dt", {
        hasText: new RegExp(`^${label}:$`),
      }),
    ).toHaveCount(0);
  }

  async closeLookupResult() {
    await this.page.getByTestId("lookup-result-close").click();
    await expect(this.lookupResultCard).toBeHidden();
  }

  async openTimersFromToolsMenu() {
    await this.openToolsMenuItem(this.timersMenuItem);
    await this.timersMenuItem.click();
    await expect(this.timersDialog).toBeVisible();
  }

  async openBotManagementFromToolsMenu() {
    await this.openToolsMenuItem(this.botManagementMenuItem);
    await this.botManagementMenuItem.click();
    await expect(this.botManagementDialog).toBeVisible();
  }

  async setChannelCentralInviteOnly(enabled: boolean) {
    await this.setChannelCentralMode("Invite Only (+i)", enabled);
  }

  async setChannelCentralModerated(enabled: boolean) {
    await this.setChannelCentralMode("Moderated (+m)", enabled);
  }

  async setChannelCentralTopic(topic: string) {
    await this.switchChannelCentralToTab("general");
    const panel = this.channelCentralPanel("general");
    await panel.locator('input[name="topic"]').fill(topic);
    await panel.getByRole("button", { name: "Save Topic" }).click();
    await expect(panel.locator('input[name="topic"]')).toHaveValue(topic);
  }

  async expectChannelCentralTopic(topic: string) {
    await this.switchChannelCentralToTab("general");
    await expect(
      this.channelCentralPanel("general").locator('input[name="topic"]'),
    ).toHaveValue(topic);
  }

  async setChannelCentralMode(
    label: ChannelCentralModeLabel,
    enabled: boolean,
  ) {
    await this.switchChannelCentralToTab("modes");
    const panel = this.channelCentralPanel("modes");
    const toggle = panel.getByLabel(label);

    if ((await toggle.isChecked()) !== enabled) {
      await toggle.click();
    }

    await panel.getByRole("button", { name: "Apply Modes" }).click();

    if (enabled) {
      await expect(toggle).toBeChecked();
    } else {
      await expect(toggle).not.toBeChecked();
    }
  }

  async expectChannelCentralMode(
    label: ChannelCentralModeLabel,
    enabled: boolean,
  ) {
    await this.switchChannelCentralToTab("modes");
    const toggle = this.channelCentralPanel("modes").getByLabel(label);

    if (enabled) {
      await expect(toggle).toBeChecked();
    } else {
      await expect(toggle).not.toBeChecked();
    }
  }

  async addChannelCentralBan(nick: string) {
    await this.addChannelCentralListEntry("bans", nick);
  }

  async addChannelCentralBanException(nick: string) {
    await this.addChannelCentralListEntry("ban_exceptions", nick);
  }

  async removeChannelCentralBanException(nick: string) {
    await this.removeChannelCentralListEntry("ban_exceptions", nick);
  }

  async addChannelCentralInviteException(nick: string) {
    await this.addChannelCentralListEntry("invite_exceptions", nick);
  }

  async removeChannelCentralInviteException(nick: string) {
    await this.removeChannelCentralListEntry("invite_exceptions", nick);
  }

  async switchChannelCentralToAccessList(list: ChannelCentralAccessList) {
    await this.switchChannelCentralToTab("access_lists");
    await this.channelCentralDialog.getByTestId(`cc-list-type-${list}`).click();
  }

  async addChannelCentralListEntry(
    list: ChannelCentralAccessList,
    nick: string,
  ) {
    await this.switchChannelCentralToAccessList(list);
    const panel = this.channelCentralPanel("access_lists");
    await panel.getByRole("button", { name: "Add" }).click();
    const dialog = this.page.getByTestId("cc-add-list-entry-dialog");
    await expect(dialog).toHaveAttribute("data-access-list", list);
    await dialog.getByTestId("cc-list-entry-input").fill(nick);
    await dialog.getByRole("button", { name: "OK" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(this.channelCentralEntry(nick)).toBeVisible();
  }

  async removeChannelCentralListEntry(
    list: ChannelCentralAccessList,
    nick: string,
  ) {
    await this.switchChannelCentralToAccessList(list);
    const row = this.channelCentralEntry(nick);
    await expect(row).toBeVisible();
    await row.click();
    await this.channelCentralPanel("access_lists")
      .getByRole("button", { name: "Remove" })
      .click();
    await expect(this.channelCentralEntry(nick)).toHaveCount(0);
  }

  // Opens the Tools menu and waits for `item` to be visible, retrying the
  // trigger click. The MenuBarHook toggles a `u-hidden` class on mousedown, but
  // a LiveView re-render right after connect (join/presence) can re-apply the
  // server-rendered `u-hidden` and close the just-opened dropdown — the known
  // first-menu-open flake. Retrying the whole open absorbs that race.
  async openToolsMenuItem(item: Locator) {
    await expect(async () => {
      await this.toolsMenuTrigger.click();
      await expect(item).toBeVisible({ timeout: 1000 });
    }).toPass({ timeout: 10_000 });
  }

  async openAddressBookFromMenu() {
    await this.openToolsMenuItem(this.addressBookMenuItem);
    await this.addressBookMenuItem.click();
    await expect(this.addressBookDialog).toBeVisible();
  }

  async openAliasEditorFromMenu() {
    await this.openToolsMenuItem(this.aliasEditorMenuItem);
    await this.aliasEditorMenuItem.click();
    await expect(this.aliasDialog).toBeVisible();
  }

  async openHighlightDialogFromMenu() {
    await this.openToolsMenuItem(this.highlightWordsMenuItem);
    await this.highlightWordsMenuItem.click();
    await expect(this.highlightDialog).toBeVisible();
  }

  async openPerformDialogFromMenu() {
    await this.openToolsMenuItem(this.performMenuItem);
    await this.performMenuItem.click();
    await expect(this.performDialog).toBeVisible();
  }

  async openSoundSettingsFromMenu() {
    await this.openToolsMenuItem(this.soundSettingsMenuItem);
    await this.soundSettingsMenuItem.click();
    await expect(this.soundSettingsDialog).toBeVisible();
  }

  async openUrlCatcherFromMenu() {
    await this.openToolsMenuItem(this.urlCatcherMenuItem);
    await this.urlCatcherMenuItem.click();
    await expect(this.urlCatcherDialog).toBeVisible();
  }

  async openAutorespondDialogFromMenu() {
    await this.openToolsMenuItem(this.autorespondMenuItem);
    await this.autorespondMenuItem.click();
    await expect(this.autorespondDialog).toBeVisible();
  }

  async openNotifyListFromCommand() {
    await this.sendMessage("/notify");
    await expect(this.notifyListDialog).toBeVisible();
  }

  async openCustomMenusDialogFromMenu() {
    await this.openToolsMenuItem(this.customMenusMenuItem);
    await this.customMenusMenuItem.click();
    await expect(this.customMenusDialog).toBeVisible();
  }

  taskbarGroup(family: string): Locator {
    return this.page.getByTestId(`taskbar-group-${family}`);
  }

  taskbarGroupPanel(family: string): Locator {
    return this.taskbarGroup(family)
      .locator("xpath=..")
      .locator("[data-taskbar-group-panel]");
  }

  taskbarButton(windowId: string): Locator {
    return this.page.locator(`[data-window-taskbar="${windowId}"]`).first();
  }

  // The pinned chat window. Its title bar is named after the active
  // conversation, like the taskbar button and the browser tab.
  get chatWindow(): Locator {
    return this.page.getByTestId("chat-window");
  }

  // The chat window's title bar: it names the conversation and the viewer, and
  // its meta zone carries the identity state the status bar used to show.
  get chatWindowTitleBar(): Locator {
    return this.chatWindow.locator("[data-window-titlebar]");
  }

  async openNickColorsFromMenu() {
    await this.openToolsMenuItem(this.nickColorsMenuItem);
    await this.nickColorsMenuItem.click();
    await expect(this.nickColorsDialog).toBeVisible();
  }

  async openIgnoreListFromMenu() {
    await this.openToolsMenuItem(this.ignoreListMenuItem);
    await this.ignoreListMenuItem.click();
    await expect(this.ignoreListDialog).toBeVisible();
  }

  async addAddressBookContact(nick: string, note: string) {
    await this.addressBookDialog.getByTestId("contact-add").click();
    const form = this.page.getByTestId("contact-add-form");
    await expect(form).toBeVisible();
    await form.locator("#contact-add-nick").fill(nick);
    await form.locator("#contact-add-note").fill(note);
    await form.getByRole("button", { name: "OK" }).click();
    await expect(this.addressBookContactRow(nick)).toContainText(note);
  }

  async addAddressBookNickColor(nick: string, colorIndex: number) {
    await this.openNickColorsFromMenu();
    await this.nickColorsDialog.getByTestId("nick-color-add").click();
    const form = this.page.getByTestId("nick-color-add-form");
    await expect(form).toBeVisible();
    await form.locator("#nick-color-add-nick").fill(nick);
    await form
      .getByRole("button", { name: new RegExp(`^Color ${colorIndex}:`) })
      .click();
    await form.getByRole("button", { name: "OK" }).click();
    await expect(this.addressBookNickColorRow(nick)).toHaveAttribute(
      "data-color-index",
      String(colorIndex),
    );
  }

  async editAddressBookNickColor(nick: string, colorIndex: number) {
    await this.openNickColorsFromMenu();
    await this.addressBookNickColorRow(nick).click();
    await this.nickColorsDialog.getByTestId("nick-color-edit").click();
    const form = this.page.getByTestId("nick-color-edit-form");
    await expect(form).toBeVisible();
    await form
      .getByRole("button", { name: new RegExp(`^Color ${colorIndex}:`) })
      .click();
    await form.getByRole("button", { name: "OK" }).click();
    await expect(this.addressBookNickColorRow(nick)).toHaveAttribute(
      "data-color-index",
      String(colorIndex),
    );
  }

  async removeAddressBookNickColor(nick: string) {
    await this.openNickColorsFromMenu();
    await this.addressBookNickColorRow(nick).click();
    await this.nickColorsDialog.getByTestId("nick-color-remove").click();
    await expect(this.addressBookNickColorRow(nick)).toHaveCount(0);
  }

  async addAddressBookControlEntry(
    nick: string,
    type: AddressBookControlType,
    duration = "",
  ) {
    await this.openIgnoreListFromMenu();
    await this.ignoreListDialog.getByTestId("control-add").click();
    const form = this.page.getByTestId("control-add-form");
    await expect(form).toBeVisible();
    await form.locator("#control-add-nick").fill(nick);
    await form.locator("#control-add-type").selectOption(type);
    await form.locator("#control-add-duration").fill(duration);
    await form.getByRole("button", { name: "OK" }).click();
    await expect(this.addressBookControlRow(nick)).toContainText(type);
  }

  async removeAddressBookControlEntry(nick: string) {
    await this.openIgnoreListFromMenu();
    await this.addressBookControlRow(nick).click();
    await this.ignoreListDialog.getByTestId("control-remove").click();
    await expect(this.addressBookControlRow(nick)).toHaveCount(0);
  }

  async closeAddressBook() {
    await this.addressBookDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(this.addressBookDialog).toBeHidden();
  }

  async closeNotifyList() {
    await this.notifyListDialog
      .getByRole("button", { name: "Close" })
      .last()
      .click();
    await expect(this.notifyListDialog).toBeHidden();
  }

  async setNotifyAutoAddPm(enabled: boolean) {
    if ((await this.notifyAutoAddPmToggle.isChecked()) !== enabled) {
      await this.notifyAutoAddPmToggle.click();
    }

    if (enabled) {
      await expect(this.notifyAutoAddPmToggle).toBeChecked();
    } else {
      await expect(this.notifyAutoAddPmToggle).not.toBeChecked();
    }
  }

  async setNotifyAutoWhois(enabled: boolean) {
    if ((await this.notifyAutoWhoisToggle.isChecked()) !== enabled) {
      await this.notifyAutoWhoisToggle.click();
    }

    if (enabled) {
      await expect(this.notifyAutoWhoisToggle).toBeChecked();
    } else {
      await expect(this.notifyAutoWhoisToggle).not.toBeChecked();
    }
  }

  async closeChannelCentral() {
    await this.channelCentralDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(this.channelCentralDialog).toBeHidden();
  }

  async addAliasFromDialog(name: string, expansion: string) {
    await this.startAliasAdd();
    await this.fillAliasDraft(name, expansion);
    await this.saveAliasDraft();
    await expect(this.aliasEditForm).toBeHidden();
    await expect(this.aliasRow(name)).toContainText(expansion);
  }

  async editAliasFromDialog(name: string, expansion: string) {
    await this.aliasRow(name).click();
    await this.aliasDialog.getByRole("button", { name: "Edit" }).click();
    await expect(this.aliasEditForm).toBeVisible();
    await this.aliasEditForm
      .getByTestId("alias-expansion-input")
      .fill(expansion);
    await this.saveAliasDraft();
    await expect(this.aliasEditForm).toBeHidden();
    await expect(this.aliasRow(name)).toContainText(expansion);
  }

  async removeAliasFromDialog(name: string) {
    await this.aliasRow(name).click();
    await this.aliasDialog.getByRole("button", { name: "Remove" }).click();
    await expect(this.aliasRow(name)).toHaveCount(0);
  }

  async closeAliasEditor() {
    await this.aliasDialog
      .getByRole("button", { name: "Close" })
      .last()
      .click();
    await expect(this.aliasDialog).toBeHidden();
  }

  async startAliasAdd() {
    await this.aliasDialog.getByRole("button", { name: "Add" }).click();
    await expect(this.aliasEditForm).toBeVisible();
  }

  async fillAliasDraft(name: string, expansion: string) {
    await this.aliasEditForm.getByTestId("alias-name-input").fill(name);
    await this.aliasEditForm
      .getByTestId("alias-expansion-input")
      .fill(expansion);
  }

  async saveAliasDraft() {
    await this.aliasEditForm.getByRole("button", { name: "Save" }).click();
  }

  async cancelAliasDraft() {
    await this.aliasEditForm.getByRole("button", { name: "Cancel" }).click();
    await expect(this.aliasEditForm).toBeHidden();
  }

  async expectAliasError(text: string) {
    await expect(this.aliasEditForm.getByTestId("alias-error")).toContainText(
      text,
    );
  }

  highlightWordRow(word: string): Locator {
    return this.page.getByTestId(`highlight-word-row-${word}`);
  }

  highlightWordColor(word: string): Locator {
    return this.page.getByTestId(`highlight-word-color-${word}`);
  }

  async addHighlightWord(word: string, colorIndex: number) {
    await this.highlightDialog.getByRole("button", { name: "Add" }).click();
    await expect(this.highlightAddForm).toBeVisible();
    await this.highlightWordInput.fill(word);
    await this.highlightAddForm
      .getByRole("button", { name: new RegExp(`^Color ${colorIndex}:`) })
      .click();
    await this.highlightAddForm.getByRole("button", { name: "Add" }).click();
    await expect(this.highlightAddForm).toBeHidden();
    await expect(this.highlightWordRow(word)).toBeVisible();
  }

  async editHighlightWordColor(word: string, colorIndex: number) {
    await this.highlightWordRow(word).click();
    await this.highlightDialog.getByRole("button", { name: "Edit" }).click();
    await expect(this.highlightEditForm).toBeVisible();
    await this.highlightEditForm
      .getByRole("button", { name: new RegExp(`^Color ${colorIndex}:`) })
      .click();
    await this.highlightEditForm.getByRole("button", { name: "OK" }).click();
    await expect(this.highlightEditForm).toBeHidden();
  }

  async removeHighlightWord(word: string) {
    await this.highlightWordRow(word).click();
    await this.highlightDialog.getByRole("button", { name: "Remove" }).click();
    await expect(this.highlightWordRow(word)).toHaveCount(0);
  }

  soundSelect(event: string): Locator {
    return this.soundSettingsDialog.getByTestId(`sound-select-${event}`);
  }

  soundSelectLabel(event: string): Locator {
    return this.soundSelect(event).locator(".select-value");
  }

  soundFlashToggle(event: string): Locator {
    return this.soundSettingsDialog.getByTestId(`flash-toggle-${event}`);
  }

  soundPreviewButton(event: string): Locator {
    return this.soundSettingsDialog.getByTestId(`sound-preview-${event}`);
  }

  async selectSound(event: string, label: string) {
    const select = this.soundSelect(event);
    const content = select.locator(".select-content");

    if (!(await content.isVisible())) {
      await select.getByRole("button").click();
    }

    await expect(content).toBeVisible();
    await select
      .getByRole("option", { name: label, exact: true })
      .getByText(label, { exact: true })
      .click();
    await expect(content).toBeHidden();
    await expect(this.soundSelectLabel(event)).toHaveAttribute(
      "data-content",
      label,
    );
  }

  async expectSoundSelected(event: string, label: string) {
    await expect(this.soundSelectLabel(event)).toHaveAttribute(
      "data-content",
      label,
    );
  }

  async setSoundFlash(event: string, enabled: boolean) {
    const toggle = this.soundFlashToggle(event);

    if ((await toggle.isChecked()) !== enabled) {
      await toggle.click();
    }

    if (enabled) {
      await expect(toggle).toBeChecked();
    } else {
      await expect(toggle).not.toBeChecked();
    }
  }

  performCommandRow(command: string): Locator {
    return this.performCommandsPanel()
      .getByTestId("perform-command-row")
      .filter({ hasText: command })
      .first();
  }

  performEnabledCheckbox(): Locator {
    return this.performCommandsPanel().getByLabel("Enable perform on connect");
  }

  performCommandsPanel(): Locator {
    return this.performDialog.getByTestId("perform-panel");
  }

  autojoinPanel(): Locator {
    return this.autojoinDialog.getByTestId("autojoin-panel");
  }

  async addPerformCommand(command: string) {
    await this.performCommandsPanel()
      .getByRole("button", { name: "Add" })
      .click();
    await expect(this.performAddDialog).toBeVisible();
    await this.performAddDialog.locator("#perform-command-input").fill(command);
    await this.performAddDialog.getByRole("button", { name: "OK" }).click();
    await expect(this.performAddDialog).toBeHidden();
    await expect(this.performCommandRow(command)).toBeVisible();
  }

  async editPerformCommand(command: string, replacement: string) {
    await this.performCommandRow(command).click();
    await this.performCommandsPanel()
      .getByRole("button", { name: "Edit" })
      .click();
    await expect(this.performEditDialog).toBeVisible();
    await this.performEditDialog
      .locator("#perform-edit-input")
      .fill(replacement);
    await this.performEditDialog.getByRole("button", { name: "OK" }).click();
    await expect(this.performEditDialog).toBeHidden();
    await expect(this.performCommandRow(replacement)).toBeVisible();
  }

  async movePerformCommandUp(command: string) {
    await this.performCommandRow(command).click();
    await this.performCommandsPanel()
      .getByRole("button", { name: "Up" })
      .click();
  }

  async closePerformDialog() {
    await this.performDialog.locator('[data-window-control="close"]').click();
    await expect(this.performDialog).toBeHidden();
  }

  async openAutojoinDialogFromMenu() {
    await this.openToolsMenuItem(this.autojoinMenuItem);
    await this.autojoinMenuItem.click();
    await expect(this.autojoinDialog).toBeVisible();
  }

  async closeAutojoinDialog() {
    await this.autojoinDialog.locator('[data-window-control="close"]').click();
    await expect(this.autojoinDialog).toBeHidden();
  }

  autojoinRow(channel: string): Locator {
    return this.autojoinPanel()
      .getByTestId("autojoin-row")
      .filter({ hasText: channel })
      .first();
  }

  async addAutojoinEntry(channel: string, key = "") {
    await this.autojoinPanel().getByRole("button", { name: "Add" }).click();
    await expect(this.autojoinAddDialog).toBeVisible();
    await this.autojoinAddDialog
      .locator("#autojoin-channel-input")
      .fill(channel);
    await this.autojoinAddDialog.locator("#autojoin-key-input").fill(key);
    await this.autojoinAddDialog.getByRole("button", { name: "OK" }).click();
    await expect(this.autojoinAddDialog).toBeHidden();
    await expect(this.autojoinRow(channel)).toBeVisible();
  }

  async editAutojoinKey(channel: string, key: string) {
    await this.autojoinRow(channel).click();
    await this.autojoinPanel().getByRole("button", { name: "Edit" }).click();
    await expect(this.autojoinEditDialog).toBeVisible();
    await this.autojoinEditDialog.locator("#autojoin-edit-key").fill(key);
    await this.autojoinEditDialog.getByRole("button", { name: "OK" }).click();
    await expect(this.autojoinEditDialog).toBeHidden();
  }

  async removeAutojoinEntry(channel: string) {
    await this.autojoinRow(channel).click();
    await this.autojoinPanel().getByRole("button", { name: "Remove" }).click();
    await expect(this.autojoinRow(channel)).toHaveCount(0);
  }

  autorespondRuleRow(text: string): Locator {
    return this.autorespondDialog
      .getByTestId("autorespond-rule-row")
      .filter({ hasText: text })
      .first();
  }

  autorespondRuleToggle(text: string): Locator {
    return this.autorespondRuleRow(text)
      .locator('input[type="checkbox"]')
      .first();
  }

  async startAutorespondAdd() {
    await this.autorespondDialog.getByRole("button", { name: "Add" }).click();
    await expect(this.autorespondEditForm).toBeVisible();
  }

  async fillAutorespondDraft(channel: string, command: string) {
    await this.autorespondEditForm
      .locator('input[name="channel"]')
      .fill(channel);
    await this.autorespondEditForm.locator('[name="command"]').fill(command);
  }

  async saveAutorespondDraft() {
    await this.autorespondEditForm
      .getByRole("button", { name: "Save" })
      .click();
  }

  async addAutorespondRule(channel: string, command: string) {
    await this.startAutorespondAdd();
    await this.fillAutorespondDraft(channel, command);
    await this.saveAutorespondDraft();
    await expect(this.autorespondEditForm).toBeHidden();
    await expect(this.autorespondRuleRow(command)).toBeVisible();
  }

  async editAutorespondRule(command: string, replacement: string) {
    await this.autorespondRuleRow(command).click();
    await this.autorespondDialog.getByRole("button", { name: "Edit" }).click();
    await expect(this.autorespondEditForm).toBeVisible();
    await this.autorespondEditForm
      .locator('[name="command"]')
      .fill(replacement);
    await this.saveAutorespondDraft();
    await expect(this.autorespondEditForm).toBeHidden();
    await expect(this.autorespondRuleRow(replacement)).toBeVisible();
  }

  async removeAutorespondRule(text: string) {
    await this.autorespondRuleRow(text).click();
    await this.autorespondDialog
      .getByRole("button", { name: "Remove" })
      .click();
    await expect(this.autorespondRuleRow(text)).toHaveCount(0);
  }

  async openCustomMenusDialogFromCommand() {
    await this.sendMessage("/popups");
    await expect(this.customMenusDialog).toBeVisible();
  }

  async switchCustomMenusTab(tab: "Nicklist" | "Channel" | "Chat") {
    await this.customMenusDialog.getByRole("button", { name: tab }).click();
    await expect(this.customMenuPanel(tab)).toBeVisible();
  }

  async startCustomMenuAdd(tab: "Nicklist" | "Channel" | "Chat") {
    await this.switchCustomMenusTab(tab);
    await this.customMenuPanel(tab)
      .getByRole("button", { name: "Add" })
      .click();
    await expect(this.customMenuEditForm).toBeVisible();
  }

  async fillCustomMenuDraft(label: string, command: string) {
    await this.customMenuEditForm
      .getByTestId("custom-menu-label-input")
      .fill(label);
    await this.customMenuEditForm
      .getByTestId("custom-menu-command-input")
      .fill(command);
  }

  async saveCustomMenuDraft() {
    await this.customMenuEditForm.getByRole("button", { name: "Save" }).click();
  }

  async expectCustomMenuError(text: string) {
    await expect(
      this.customMenuEditForm.getByTestId("custom-menu-error"),
    ).toContainText(text);
  }

  async addCustomMenuItem(
    tab: "Nicklist" | "Channel" | "Chat",
    label: string,
    command: string,
  ) {
    await this.startCustomMenuAdd(tab);
    await this.fillCustomMenuDraft(label, command);
    await this.saveCustomMenuDraft();
    await expect(this.customMenuEditForm).toBeHidden();
    await expect(this.customMenuRowInTab(tab, label)).toContainText(command);
  }

  async closeCustomMenusDialog() {
    await this.customMenusDialog.getByRole("button", { name: "OK" }).click();
    await expect(this.customMenusDialog).toBeHidden();
  }

  async confirmNickChange(password?: string) {
    await expect(this.nickChangeDialog).toBeVisible();

    if (password !== undefined) {
      await expect(this.nickChangePassword).toBeVisible();
      await this.nickChangePassword.fill("");
      await this.nickChangePassword.pressSequentially(password);
    }

    await this.nickChangeConfirmButton.click();

    if (password === undefined) {
      await expect(this.nickChangeDialog).toBeHidden();
      await this.waitUntilConnected();
      return;
    }

    const outcome = await Promise.race([
      this.nickChangeDialog
        .waitFor({ state: "hidden", timeout: 5_000 })
        .then(() => "success" as const),
      this.nickChangeError
        .waitFor({ state: "visible", timeout: 5_000 })
        .then(() => "error" as const),
    ]).catch(() => "unknown" as const);

    if (outcome === "success") {
      await this.waitUntilConnected();
    }
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
