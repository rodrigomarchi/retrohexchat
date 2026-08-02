defmodule RetroHexChatWeb.ShowcaseCatalog do
  @moduledoc """
  The showcase's single source of truth: one entry per component page.

  Routes, the navigator tree, the Start menu, the index page's category cards,
  the sitemap and the smoke test all read from `entries/0`. Adding a component
  is an edit here and nowhere else — the list used to live in three places at
  once (router, navigation, index counters) and the three had drifted apart.

  Labels are stored as extraction markers and translated at call time by
  `label/1` and `group_label/1`, so the catalog itself holds no locale state.
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.ShowcaseLive.Assets
  alias RetroHexChatWeb.ShowcaseLive.Chat
  alias RetroHexChatWeb.ShowcaseLive.Dialogs
  alias RetroHexChatWeb.ShowcaseLive.Games
  alias RetroHexChatWeb.ShowcaseLive.Layout
  alias RetroHexChatWeb.ShowcaseLive.P2P
  alias RetroHexChatWeb.ShowcaseLive.Primitives
  alias RetroHexChatWeb.ShowcaseLive.Shell

  @type entry :: %{
          id: String.t(),
          group: atom(),
          module: module(),
          label: String.t(),
          icon: atom()
        }

  @type group :: %{
          key: atom(),
          label: String.t(),
          icon: atom(),
          description: String.t(),
          count: non_neg_integer()
        }

  @root "/showcase"

  # Group order here is the order the index page and the Start menu present.
  @groups [
    %{
      key: :primitives,
      label: dgettext_noop("showcase", "Primitives"),
      icon: :icon_btn_ok,
      description:
        dgettext_noop(
          "showcase",
          "SaladUI base widgets — buttons, inputs, badges, toggles, selects, and other atomic form controls."
        )
    },
    %{
      key: :layout,
      label: dgettext_noop("showcase", "Layout"),
      icon: :icon_group_view,
      description:
        dgettext_noop(
          "showcase",
          "Structural containers — dialogs, tabs, tables, menus, tree views, windows, and scroll areas."
        )
    },
    %{
      key: :chat,
      label: dgettext_noop("showcase", "Chat"),
      icon: :icon_chat,
      description:
        dgettext_noop(
          "showcase",
          "Chat-specific components — messages, nicklist, emoji picker, formatting toolbar, context menus, and more."
        )
    },
    %{
      key: :shell,
      label: dgettext_noop("showcase", "Shell"),
      icon: :icon_laptop,
      description:
        dgettext_noop(
          "showcase",
          "Win98 app shell composites — toolbar app, status bar app, app header, config form, and empty states."
        )
    },
    %{
      key: :dialogs,
      label: dgettext_noop("showcase", "Dialogs"),
      icon: :icon_dialog_options,
      description:
        dgettext_noop(
          "showcase",
          "Complex dialog composites — channel settings, perform, address book, sound settings, and the admin console family."
        )
    },
    %{
      key: :p2p,
      label: dgettext_noop("showcase", "P2P"),
      icon: :icon_p2p,
      description:
        dgettext_noop(
          "showcase",
          "Peer-to-peer session components — connection diagram and file transfer."
        )
    },
    %{
      key: :games,
      label: dgettext_noop("showcase", "Games"),
      icon: :icon_joystick,
      description: dgettext_noop("showcase", "Arcade components — game cards and the solo lobby.")
    },
    %{
      key: :assets,
      label: dgettext_noop("showcase", "Assets"),
      icon: :icon_folder,
      description:
        dgettext_noop("showcase", "Icons catalog, SVG diagrams, and design tokens reference.")
    }
  ]

  # Router order. `nav_entries/0` re-sorts alphabetically for presentation.
  @entries [
    %{
      id: "button",
      group: :primitives,
      module: Primitives.Button,
      label: dgettext_noop("showcase", "Button"),
      icon: :icon_btn_ok
    },
    %{
      id: "input",
      group: :primitives,
      module: Primitives.Input,
      label: dgettext_noop("showcase", "Input"),
      icon: :icon_btn_edit
    },
    %{
      id: "label",
      group: :primitives,
      module: Primitives.Label,
      label: dgettext_noop("showcase", "Label"),
      icon: :icon_tag
    },
    %{
      id: "textarea",
      group: :primitives,
      module: Primitives.Textarea,
      label: dgettext_noop("showcase", "Textarea"),
      icon: :icon_notepad
    },
    %{
      id: "select",
      group: :primitives,
      module: Primitives.Select,
      label: dgettext_noop("showcase", "Select"),
      icon: :icon_btn_down
    },
    %{
      id: "checkbox",
      group: :primitives,
      module: Primitives.Checkbox,
      label: dgettext_noop("showcase", "Checkbox"),
      icon: :icon_checkmark
    },
    %{
      id: "radio-group",
      group: :primitives,
      module: Primitives.RadioGroup,
      label: dgettext_noop("showcase", "Radio Group"),
      icon: :icon_btn_ok
    },
    %{
      id: "switch",
      group: :primitives,
      module: Primitives.Switch,
      label: dgettext_noop("showcase", "Switch"),
      icon: :icon_tab_control
    },
    %{
      id: "slider",
      group: :primitives,
      module: Primitives.Slider,
      label: dgettext_noop("showcase", "Slider"),
      icon: :icon_tab_control
    },
    %{
      id: "toggle",
      group: :primitives,
      module: Primitives.Toggle,
      label: dgettext_noop("showcase", "Toggle"),
      icon: :icon_tab_control
    },
    %{
      id: "toggle-group",
      group: :primitives,
      module: Primitives.ToggleGroup,
      label: dgettext_noop("showcase", "Toggle Group"),
      icon: :icon_tab_control
    },
    %{
      id: "alert",
      group: :primitives,
      module: Primitives.Alert,
      label: dgettext_noop("showcase", "Alert"),
      icon: :icon_warning
    },
    %{
      id: "badge",
      group: :primitives,
      module: Primitives.Badge,
      label: dgettext_noop("showcase", "Badge"),
      icon: :icon_tag
    },
    %{
      id: "progress",
      group: :primitives,
      module: Primitives.Progress,
      label: dgettext_noop("showcase", "Progress"),
      icon: :icon_status_signal
    },
    %{
      id: "skeleton",
      group: :primitives,
      module: Primitives.Skeleton,
      label: dgettext_noop("showcase", "Skeleton"),
      icon: :icon_clock
    },
    %{
      id: "tooltip",
      group: :primitives,
      module: Primitives.Tooltip,
      label: dgettext_noop("showcase", "Tooltip"),
      icon: :icon_lightbulb
    },
    %{
      id: "card",
      group: :primitives,
      module: Primitives.Card,
      label: dgettext_noop("showcase", "Card"),
      icon: :icon_group_view
    },
    %{
      id: "separator",
      group: :primitives,
      module: Primitives.Separator,
      label: dgettext_noop("showcase", "Separator"),
      icon: :icon_tab_control
    },
    %{
      id: "accordion",
      group: :primitives,
      module: Primitives.Accordion,
      label: dgettext_noop("showcase", "Accordion"),
      icon: :icon_btn_down
    },
    %{
      id: "avatar",
      group: :primitives,
      module: Primitives.Avatar,
      label: dgettext_noop("showcase", "Avatar"),
      icon: :icon_status_user
    },
    %{
      id: "breadcrumb",
      group: :primitives,
      module: Primitives.BreadcrumbPage,
      label: dgettext_noop("showcase", "Breadcrumb"),
      icon: :icon_btn_next
    },
    %{
      id: "dropdown-menu",
      group: :primitives,
      module: Primitives.DropdownMenuPage,
      label: dgettext_noop("showcase", "Dropdown Menu"),
      icon: :icon_btn_down
    },
    %{
      id: "alert-dialog",
      group: :primitives,
      module: Primitives.AlertDialogPage,
      label: dgettext_noop("showcase", "Alert Dialog"),
      icon: :icon_warning
    },
    %{
      id: "popover",
      group: :primitives,
      module: Primitives.PopoverPage,
      label: dgettext_noop("showcase", "Popover"),
      icon: :icon_lightbulb
    },
    %{
      id: "sheet",
      group: :primitives,
      module: Primitives.SheetPage,
      label: dgettext_noop("showcase", "Sheet"),
      icon: :icon_group_view
    },
    %{
      id: "form",
      group: :primitives,
      module: Primitives.FormPage,
      label: dgettext_noop("showcase", "Form"),
      icon: :icon_btn_edit
    },
    %{
      id: "tabs",
      group: :layout,
      module: Layout.Tabs,
      label: dgettext_noop("showcase", "Tabs"),
      icon: :icon_tab_general
    },
    %{
      id: "table",
      group: :layout,
      module: Layout.Table,
      label: dgettext_noop("showcase", "Table"),
      icon: :icon_database
    },
    %{
      id: "window",
      group: :layout,
      module: Layout.Window,
      label: dgettext_noop("showcase", "Window"),
      icon: :icon_laptop
    },
    %{
      id: "desktop",
      group: :layout,
      module: Layout.Desktop,
      label: dgettext_noop("showcase", "Desktop"),
      icon: :icon_group_view
    },
    %{
      id: "dialog",
      group: :layout,
      module: Layout.DialogPage,
      label: dgettext_noop("showcase", "Dialog"),
      icon: :icon_dialog_options
    },
    %{
      id: "menu",
      group: :layout,
      module: Layout.MenuPage,
      label: dgettext_noop("showcase", "Menu"),
      icon: :icon_dialog_custom_menus
    },
    %{
      id: "toolbar",
      group: :layout,
      module: Layout.ToolbarPage,
      label: dgettext_noop("showcase", "Toolbar"),
      icon: :icon_group_tools
    },
    %{
      id: "fieldset",
      group: :layout,
      module: Layout.FieldsetPage,
      label: dgettext_noop("showcase", "Fieldset"),
      icon: :icon_group_view
    },
    %{
      id: "context-menu",
      group: :layout,
      module: Layout.ContextMenuPage,
      label: dgettext_noop("showcase", "Context Menu"),
      icon: :icon_dialog_custom_menus
    },
    %{
      id: "scroll-area",
      group: :layout,
      module: Layout.ScrollAreaPage,
      label: dgettext_noop("showcase", "Scroll Area"),
      icon: :icon_btn_down
    },
    %{
      id: "list-states",
      group: :layout,
      module: Layout.ListStatesPage,
      label: dgettext_noop("showcase", "List States"),
      icon: :icon_btn_channel_list
    },
    %{
      id: "toast",
      group: :layout,
      module: Layout.ToastPage,
      label: dgettext_noop("showcase", "Toast"),
      icon: :icon_btn_bell
    },
    %{
      id: "tree-view",
      group: :layout,
      module: Layout.TreeViewPage,
      label: dgettext_noop("showcase", "Tree View"),
      icon: :icon_folder
    },
    %{
      id: "irc-tabs",
      group: :chat,
      module: Chat.IrcTabsPage,
      label: dgettext_noop("showcase", "IRC Tabs"),
      icon: :icon_tab_channel
    },
    %{
      id: "chat-message",
      group: :chat,
      module: Chat.ChatMessagePage,
      label: dgettext_noop("showcase", "Chat Message"),
      icon: :icon_chat
    },
    %{
      id: "chat-input",
      group: :chat,
      module: Chat.ChatInputPage,
      label: dgettext_noop("showcase", "Chat Input"),
      icon: :icon_send
    },
    %{
      id: "nicklist",
      group: :chat,
      module: Chat.NicklistPage,
      label: dgettext_noop("showcase", "Nicklist"),
      icon: :icon_tab_nicklist
    },
    %{
      id: "conversations",
      group: :chat,
      module: Chat.ConversationsPage,
      label: dgettext_noop("showcase", "Conversations"),
      icon: :icon_tab_conversations
    },
    %{
      id: "hover-card",
      group: :chat,
      module: Chat.HoverCardPage,
      label: dgettext_noop("showcase", "Hover Card"),
      icon: :icon_status_user
    },
    %{
      id: "search-bar",
      group: :chat,
      module: Chat.SearchBarPage,
      label: dgettext_noop("showcase", "Search Bar"),
      icon: :icon_btn_find
    },
    %{
      id: "topic-bar",
      group: :chat,
      module: Chat.TopicBarPage,
      label: dgettext_noop("showcase", "Topic Bar"),
      icon: :icon_tab_channel
    },
    %{
      id: "formatting-toolbar",
      group: :chat,
      module: Chat.FormattingToolbarPage,
      label: dgettext_noop("showcase", "Formatting Toolbar"),
      icon: :icon_fmt_bold
    },
    %{
      id: "emoji-picker",
      group: :chat,
      module: Chat.EmojiPickerPage,
      label: dgettext_noop("showcase", "Emoji Picker"),
      icon: :icon_fmt_emoji
    },
    %{
      id: "autocomplete",
      group: :chat,
      module: Chat.AutocompletePage,
      label: dgettext_noop("showcase", "Autocomplete"),
      icon: :icon_btn_down
    },
    %{
      id: "tab-bar",
      group: :chat,
      module: Chat.TabBarPage,
      label: dgettext_noop("showcase", "Tab Bar"),
      icon: :icon_tab_channel
    },
    %{
      id: "reply-bar",
      group: :chat,
      module: Chat.ReplyBarPage,
      label: dgettext_noop("showcase", "Reply Bar"),
      icon: :icon_retry
    },
    %{
      id: "connection-status",
      group: :chat,
      module: Chat.ConnectionStatusPage,
      label: dgettext_noop("showcase", "Connection Status"),
      icon: :icon_status_signal
    },
    %{
      id: "color-picker",
      group: :chat,
      module: Chat.ColorPickerPage,
      label: dgettext_noop("showcase", "Color Picker"),
      icon: :icon_tab_colors
    },
    %{
      id: "history-search",
      group: :chat,
      module: Chat.HistorySearchPage,
      label: dgettext_noop("showcase", "History Search"),
      icon: :icon_btn_find
    },
    %{
      id: "chat-layout",
      group: :chat,
      module: Chat.ChatLayoutPage,
      label: dgettext_noop("showcase", "Chat Layout"),
      icon: :icon_chat
    },
    %{
      id: "conversations-context-menu",
      group: :chat,
      module: Chat.ConversationsContextMenuPage,
      label: dgettext_noop("showcase", "Conversations Ctx Menu"),
      icon: :icon_tab_conversations
    },
    %{
      id: "chat-context-menu",
      group: :chat,
      module: Chat.ChatContextMenuPage,
      label: dgettext_noop("showcase", "Chat Context Menu"),
      icon: :icon_dialog_custom_menus
    },
    %{
      id: "syntax-tooltip",
      group: :chat,
      module: Chat.SyntaxTooltipPage,
      label: dgettext_noop("showcase", "Syntax Tooltip"),
      icon: :icon_lightbulb
    },
    %{
      id: "status-bar",
      group: :shell,
      module: Shell.StatusBar,
      label: dgettext_noop("showcase", "Status Bar"),
      icon: :icon_status_signal
    },
    %{
      id: "toolbar-app",
      group: :shell,
      module: Shell.ToolbarAppPage,
      label: dgettext_noop("showcase", "Toolbar App"),
      icon: :icon_group_tools
    },
    %{
      id: "status-bar-app",
      group: :shell,
      module: Shell.StatusBarAppPage,
      label: dgettext_noop("showcase", "Status Bar App"),
      icon: :icon_status_signal
    },
    %{
      id: "app-header",
      group: :shell,
      module: Shell.AppHeaderPage,
      label: dgettext_noop("showcase", "App Header"),
      icon: :icon_laptop
    },
    %{
      id: "loading-spinner",
      group: :shell,
      module: Shell.LoadingSpinnerPage,
      label: dgettext_noop("showcase", "Loading Spinner"),
      icon: :icon_clock
    },
    %{
      id: "empty-state",
      group: :shell,
      module: Shell.EmptyStatePage,
      label: dgettext_noop("showcase", "Empty State"),
      icon: :icon_group_view
    },
    %{
      id: "config-form",
      group: :shell,
      module: Shell.ConfigFormPage,
      label: dgettext_noop("showcase", "Config Form"),
      icon: :icon_btn_settings
    },
    %{
      id: "confirm-dialog",
      group: :dialogs,
      module: Dialogs.ConfirmDialogPage,
      label: dgettext_noop("showcase", "Confirm Dialog"),
      icon: :icon_warning
    },
    %{
      id: "address-book",
      group: :dialogs,
      module: Dialogs.AddressBookPage,
      label: dgettext_noop("showcase", "Address Book"),
      icon: :icon_dialog_address_book
    },
    %{
      id: "nick-colors",
      group: :dialogs,
      module: Dialogs.NickColorsPage,
      label: dgettext_noop("showcase", "Nick Colors"),
      icon: :icon_dialog_nick_colors
    },
    %{
      id: "ignore-list",
      group: :dialogs,
      module: Dialogs.IgnoreListPage,
      label: dgettext_noop("showcase", "Ignore List"),
      icon: :icon_dialog_ignore_list
    },
    %{
      id: "about-dialog",
      group: :dialogs,
      module: Dialogs.AboutDialogPage,
      label: dgettext_noop("showcase", "About Dialog"),
      icon: :icon_lightbulb
    },
    %{
      id: "channel-list",
      group: :dialogs,
      module: Dialogs.ChannelListPage,
      label: dgettext_noop("showcase", "Channel List"),
      icon: :icon_channels
    },
    %{
      id: "highlight-dialog",
      group: :dialogs,
      module: Dialogs.HighlightDialogPage,
      label: dgettext_noop("showcase", "Highlight Dialog"),
      icon: :icon_star
    },
    %{
      id: "kick-dialog",
      group: :dialogs,
      module: Dialogs.KickDialogPage,
      label: dgettext_noop("showcase", "Kick Dialog"),
      icon: :icon_dialog_kick
    },
    %{
      id: "delete-confirm-dialog",
      group: :dialogs,
      module: Dialogs.DeleteConfirmDialogPage,
      label: dgettext_noop("showcase", "Delete Confirm"),
      icon: :icon_dialog_delete
    },
    %{
      id: "disconnect-confirm-dialog",
      group: :dialogs,
      module: Dialogs.DisconnectConfirmDialogPage,
      label: dgettext_noop("showcase", "Disconnect Confirm"),
      icon: :icon_btn_disconnect
    },
    %{
      id: "alias-dialog",
      group: :dialogs,
      module: Dialogs.AliasDialogPage,
      label: dgettext_noop("showcase", "Alias Dialog"),
      icon: :icon_dialog_alias
    },
    %{
      id: "flood-protection-dialog",
      group: :dialogs,
      module: Dialogs.FloodProtectionDialogPage,
      label: dgettext_noop("showcase", "Flood Protection"),
      icon: :icon_dialog_flood
    },
    %{
      id: "notify-list",
      group: :dialogs,
      module: Dialogs.NotifyListPage,
      label: dgettext_noop("showcase", "Notify List"),
      icon: :icon_btn_bell
    },
    %{
      id: "url-catcher",
      group: :dialogs,
      module: Dialogs.UrlCatcherPage,
      label: dgettext_noop("showcase", "URL Catcher"),
      icon: :icon_link
    },
    %{
      id: "auto-respond-dialog",
      group: :dialogs,
      module: Dialogs.AutoRespondDialogPage,
      label: dgettext_noop("showcase", "Auto Respond"),
      icon: :icon_dialog_auto_respond
    },
    %{
      id: "custom-menus-dialog",
      group: :dialogs,
      module: Dialogs.CustomMenusDialogPage,
      label: dgettext_noop("showcase", "Custom Menus"),
      icon: :icon_dialog_custom_menus
    },
    %{
      id: "sound-settings-dialog",
      group: :dialogs,
      module: Dialogs.SoundSettingsDialogPage,
      label: dgettext_noop("showcase", "Sound Settings"),
      icon: :icon_dialog_sound
    },
    %{
      id: "invite-dialog",
      group: :dialogs,
      module: Dialogs.InviteDialogPage,
      label: dgettext_noop("showcase", "Invite Dialog"),
      icon: :icon_btn_join
    },
    %{
      id: "paste-confirm-dialog",
      group: :dialogs,
      module: Dialogs.PasteConfirmDialogPage,
      label: dgettext_noop("showcase", "Paste Confirm"),
      icon: :icon_warning
    },
    %{
      id: "cheatsheet-dialog",
      group: :dialogs,
      module: Dialogs.CheatsheetDialogPage,
      label: dgettext_noop("showcase", "Cheatsheet"),
      icon: :icon_btn_keyboard
    },
    %{
      id: "nick-change-dialog",
      group: :dialogs,
      module: Dialogs.NickChangeDialogPage,
      label: dgettext_noop("showcase", "Nick Change"),
      icon: :icon_status_user
    },
    %{
      id: "perform-dialog",
      group: :dialogs,
      module: Dialogs.PerformDialogPage,
      label: dgettext_noop("showcase", "Perform Dialog"),
      icon: :icon_dialog_perform
    },
    %{
      id: "autojoin-dialog",
      group: :dialogs,
      module: Dialogs.AutojoinDialogPage,
      label: dgettext_noop("showcase", "Auto-Join Dialog"),
      icon: :icon_dialog_autojoin
    },
    %{
      id: "channel-central-dialog",
      group: :dialogs,
      module: Dialogs.ChannelCentralDialogPage,
      label: dgettext_noop("showcase", "Channel Central"),
      icon: :icon_dialog_channel_central
    },
    %{
      id: "admin-console-dialog",
      group: :dialogs,
      module: Dialogs.AdminConsoleDialogPage,
      label: dgettext_noop("showcase", "Admin Console"),
      icon: :icon_dialog_admin_console
    },
    %{
      id: "admin-users-dialog",
      group: :dialogs,
      module: Dialogs.AdminUsersDialogPage,
      label: dgettext_noop("showcase", "Admin Users"),
      icon: :icon_community
    },
    %{
      id: "admin-channels-dialog",
      group: :dialogs,
      module: Dialogs.AdminChannelsDialogPage,
      label: dgettext_noop("showcase", "Admin Channels"),
      icon: :icon_channels
    },
    %{
      id: "admin-server-settings-dialog",
      group: :dialogs,
      module: Dialogs.AdminServerSettingsDialogPage,
      label: dgettext_noop("showcase", "Server Settings"),
      icon: :icon_server
    },
    %{
      id: "admin-audit-log-dialog",
      group: :dialogs,
      module: Dialogs.AdminAuditLogDialogPage,
      label: dgettext_noop("showcase", "Audit Log"),
      icon: :icon_notepad
    },
    %{
      id: "admin-motd-dialog",
      group: :dialogs,
      module: Dialogs.AdminMotdDialogPage,
      label: dgettext_noop("showcase", "MOTD"),
      icon: :icon_notepad
    },
    %{
      id: "admin-turn-dialog",
      group: :dialogs,
      module: Dialogs.AdminTurnDialogPage,
      label: dgettext_noop("showcase", "TURN"),
      icon: :icon_websocket
    },
    %{
      id: "admin-broadcast-dialog",
      group: :dialogs,
      module: Dialogs.AdminBroadcastDialogPage,
      label: dgettext_noop("showcase", "Broadcast"),
      icon: :icon_megaphone
    },
    %{
      id: "admin-danger-zone-dialog",
      group: :dialogs,
      module: Dialogs.AdminDangerZoneDialogPage,
      label: dgettext_noop("showcase", "Danger Zone"),
      icon: :icon_warning
    },
    %{
      id: "bot-management-dialog",
      group: :dialogs,
      module: Dialogs.BotManagementDialogPage,
      label: dgettext_noop("showcase", "Bot Management"),
      icon: :icon_dialog_bot_management
    },
    %{
      id: "p2p-connection-diagram",
      group: :p2p,
      module: P2P.P2PConnectionDiagramPage,
      label: dgettext_noop("showcase", "Connection Diagram"),
      icon: :icon_p2p
    },
    %{
      id: "file-transfer",
      group: :p2p,
      module: P2P.FileTransferPage,
      label: dgettext_noop("showcase", "File Transfer"),
      icon: :icon_file_send
    },
    %{
      id: "game-cards",
      group: :games,
      module: Games.GameCardsPage,
      label: dgettext_noop("showcase", "Game Cards"),
      icon: :icon_joystick
    },
    %{
      id: "solo-lobby",
      group: :games,
      module: Games.SoloLobbyPage,
      label: dgettext_noop("showcase", "Solo Lobby"),
      icon: :icon_joystick
    },
    %{
      id: "icons",
      group: :assets,
      module: Assets.Icons,
      label: dgettext_noop("showcase", "Icons"),
      icon: :icon_star
    },
    %{
      id: "diagrams",
      group: :assets,
      module: Assets.Diagrams,
      label: dgettext_noop("showcase", "Diagrams"),
      icon: :icon_code
    }
  ]

  @entries_by_id Map.new(@entries, &{&1.id, &1})

  @doc "Every component page, in router order."
  @spec entries() :: [entry()]
  def entries, do: @entries

  @doc "Every category, in presentation order, with its component count."
  @spec groups() :: [group()]
  def groups do
    counts = Enum.frequencies_by(@entries, & &1.group)

    Enum.map(@groups, fn group ->
      group
      |> Map.put(:count, Map.get(counts, group.key, 0))
      |> Map.update!(:label, &translate/1)
      |> Map.update!(:description, &translate/1)
    end)
  end

  @doc "Looks a component up by its id."
  @spec fetch(String.t()) :: {:ok, entry()} | :error
  def fetch(id), do: Map.fetch(@entries_by_id, id)

  @doc "The root path of the showcase."
  @spec root() :: String.t()
  def root, do: @root

  @doc "The public path of a component page."
  @spec path(entry() | String.t()) :: String.t()
  def path(%{id: id}), do: path(id)
  def path(id) when is_binary(id), do: @root <> "/" <> id

  @doc """
  Every indexable showcase path, the index page included.

  Feeds the sitemap and the SEO smoke tests.
  """
  @spec paths() :: [String.t()]
  def paths, do: [@root | Enum.map(@entries, &path/1)]

  @doc "Components of one category, sorted by label — navigator and Start menu order."
  @spec nav_entries(atom()) :: [entry()]
  def nav_entries(group) do
    @entries
    |> Enum.filter(&(&1.group == group))
    |> Enum.map(&Map.update!(&1, :label, fn label -> translate(label) end))
    |> Enum.sort_by(& &1.label)
  end

  @doc "The whole navigation tree: each category paired with its sorted components."
  @spec nav_tree() :: [{group(), [entry()]}]
  def nav_tree, do: Enum.map(groups(), &{&1, nav_entries(&1.key)})

  @doc "The translated label of a component."
  @spec label(entry() | String.t()) :: String.t()
  def label(%{label: label}), do: translate(label)

  def label(id) when is_binary(id) do
    case fetch(id) do
      {:ok, entry} -> label(entry)
      :error -> id
    end
  end

  @doc """
  The canonical path of a component page, or the showcase root for the index.

  Unknown ids fall back to the root rather than inventing a URL, so a page that
  is not in the catalog can never advertise itself as canonical.
  """
  @spec canonical_path(String.t()) :: String.t()
  def canonical_path("index"), do: @root

  def canonical_path(id) do
    case fetch(id) do
      {:ok, entry} -> path(entry)
      :error -> @root
    end
  end

  @doc "A search-result description for a component page."
  @spec description(String.t()) :: String.t()
  def description("index") do
    dgettext(
      "showcase",
      "Every UI component behind RetroHexChat: Win98-style windows, dialogs, chat widgets and form controls, each with a live example."
    )
  end

  def description(id) do
    case fetch(id) do
      {:ok, entry} ->
        dgettext(
          "showcase",
          "%{component} — a %{category} component in the RetroHexChat UI kit, with a live example and its Win98 styling.",
          component: label(entry),
          category: group_label(entry.group)
        )

      :error ->
        description("index")
    end
  end

  @doc "The translated label of a category."
  @spec group_label(atom()) :: String.t() | nil
  def group_label(key) do
    Enum.find_value(@groups, fn group -> group.key == key && translate(group.label) end)
  end

  defp translate(msgid), do: Gettext.dgettext(RetroHexChatWeb.Gettext, "showcase", msgid)
end
