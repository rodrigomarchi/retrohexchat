defmodule RetroHexChatWeb.Router do
  use RetroHexChatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :landing_live do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :landing_live}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/api", RetroHexChatWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
  end

  scope "/", RetroHexChatWeb do
    pipe_through :landing_live

    live "/", LandingLive.Index
    live "/about", LandingLive.About
    live "/how-it-works", LandingLive.HowItWorks
    live "/features", LandingLive.Features
    live "/privacy", LandingLive.Privacy
    live "/install", LandingLive.Install
    live "/community", LandingLive.Community
    live "/faq", LandingLive.Faq
  end

  pipeline :help do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :help}
    plug :put_secure_browser_headers
  end

  scope "/", RetroHexChatWeb do
    pipe_through :help

    get "/chat/help", HelpController, :index
    get "/chat/help/:topic", HelpController, :index
    get "/sitemap.xml", SitemapController, :index
  end

  pipeline :chat_session do
    plug RetroHexChatWeb.Plugs.CheckServerBan
  end

  scope "/", RetroHexChatWeb do
    pipe_through :browser

    # Temporary route for SVG icon review
    live "/icons", IconsLive
    live "/connect", ConnectLive
    get "/chat/session/clear", SessionController, :delete
    live "/chat", ChatLive
    live "/p2p/:token", P2PSessionLive
    live "/game/:token", GameSessionLive
    live "/solo/:token", SoloSessionLive
    live "/arcade/:token/:game_id", ArcadeGameLive
  end

  scope "/", RetroHexChatWeb do
    pipe_through [:browser, :chat_session]

    post "/chat/session", SessionController, :create
  end

  pipeline :showcase do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :showcase}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/showcase", RetroHexChatWeb.ShowcaseLive do
    pipe_through :showcase

    live "/", Index

    # Primitives
    live "/button", Primitives.Button
    live "/input", Primitives.Input
    live "/label", Primitives.Label
    live "/textarea", Primitives.Textarea
    live "/select", Primitives.Select
    live "/checkbox", Primitives.Checkbox
    live "/radio-group", Primitives.RadioGroup
    live "/switch", Primitives.Switch
    live "/slider", Primitives.Slider
    live "/toggle", Primitives.Toggle
    live "/toggle-group", Primitives.ToggleGroup
    live "/alert", Primitives.Alert
    live "/badge", Primitives.Badge
    live "/progress", Primitives.Progress
    live "/skeleton", Primitives.Skeleton
    live "/tooltip", Primitives.Tooltip
    live "/card", Primitives.Card
    live "/separator", Primitives.Separator
    live "/accordion", Primitives.Accordion
    live "/avatar", Primitives.Avatar
    live "/breadcrumb", Primitives.BreadcrumbPage
    live "/dropdown-menu", Primitives.DropdownMenuPage
    live "/pagination", Primitives.PaginationPage

    # Layout
    live "/tabs", Layout.Tabs
    live "/table", Layout.Table
    live "/window", Layout.Window
    live "/dialog", Layout.DialogPage
    live "/menu", Layout.MenuPage
    live "/toolbar", Layout.ToolbarPage
    live "/fieldset", Layout.FieldsetPage
    live "/context-menu", Layout.ContextMenuPage
    live "/scroll-area", Layout.ScrollAreaPage
    live "/toast", Layout.ToastPage
    live "/tree-view", Layout.TreeViewPage

    # Chat
    live "/irc-tabs", Chat.IrcTabsPage
    live "/chat-message", Chat.ChatMessagePage
    live "/chat-input", Chat.ChatInputPage
    live "/nicklist", Chat.NicklistPage
    live "/conversations", Chat.ConversationsPage
    live "/hover-card", Chat.HoverCardPage
    live "/search-bar", Chat.SearchBarPage
    live "/topic-bar", Chat.TopicBarPage
    live "/formatting-toolbar", Chat.FormattingToolbarPage
    live "/emoji-picker", Chat.EmojiPickerPage
    live "/autocomplete", Chat.AutocompletePage
    live "/tab-bar", Chat.TabBarPage
    live "/reply-bar", Chat.ReplyBarPage
    live "/connection-status", Chat.ConnectionStatusPage
    live "/color-picker", Chat.ColorPickerPage
    live "/scroll-loader", Chat.ScrollLoaderPage
    live "/history-search", Chat.HistorySearchPage
    live "/chat-layout", Chat.ChatLayoutPage
    live "/conversations-context-menu", Chat.ConversationsContextMenuPage
    live "/chat-context-menu", Chat.ChatContextMenuPage
    live "/syntax-tooltip", Chat.SyntaxTooltipPage

    # Shell
    live "/status-bar", Shell.StatusBar
    live "/toolbar-app", Shell.ToolbarAppPage
    live "/status-bar-app", Shell.StatusBarAppPage
    live "/app-header", Shell.AppHeaderPage
    live "/loading-spinner", Shell.LoadingSpinnerPage
    live "/empty-state", Shell.EmptyStatePage
    live "/config-form", Shell.ConfigFormPage

    # Dialogs
    live "/confirm-dialog", Dialogs.ConfirmDialogPage
    live "/options-dialog", Dialogs.OptionsDialogPage
    live "/channel-dialog", Dialogs.ChannelDialogPage
    live "/address-book", Dialogs.AddressBookPage
    live "/about-dialog", Dialogs.AboutDialogPage
    live "/channel-list", Dialogs.ChannelListPage
    live "/highlight-dialog", Dialogs.HighlightDialogPage
    live "/kick-dialog", Dialogs.KickDialogPage
    live "/delete-confirm-dialog", Dialogs.DeleteConfirmDialogPage
    live "/disconnect-confirm-dialog", Dialogs.DisconnectConfirmDialogPage
    live "/alias-dialog", Dialogs.AliasDialogPage
    live "/flood-protection-dialog", Dialogs.FloodProtectionDialogPage
    live "/ignore-list-dialog", Dialogs.IgnoreListDialogPage
    live "/notify-list", Dialogs.NotifyListPage
    live "/url-catcher", Dialogs.UrlCatcherPage
    live "/auto-respond-dialog", Dialogs.AutoRespondDialogPage
    live "/custom-menus-dialog", Dialogs.CustomMenusDialogPage
    live "/sound-settings-dialog", Dialogs.SoundSettingsDialogPage
    live "/invite-dialog", Dialogs.InviteDialogPage
    live "/paste-confirm-dialog", Dialogs.PasteConfirmDialogPage
    live "/ctcp-settings-dialog", Dialogs.CtcpSettingsDialogPage
    live "/cheatsheet-dialog", Dialogs.CheatsheetDialogPage
    live "/nick-change-dialog", Dialogs.NickChangeDialogPage
    live "/perform-dialog", Dialogs.PerformDialogPage
    live "/channel-central-dialog", Dialogs.ChannelCentralDialogPage

    # P2P
    live "/p2p-lobby", P2P.P2PLobbyPage
    live "/media-controls", P2P.MediaControlsPage
    live "/file-transfer", P2P.FileTransferPage

    # Games
    live "/game-cards", Games.GameCardsPage
    live "/game-canvas", Games.GameCanvasPage
    live "/game-lobby", Games.GameLobbyPage
    live "/solo-lobby", Games.SoloLobbyPage
    live "/arcade-frame", Games.ArcadeFramePage

    # Assets
    live "/icons", Assets.Icons
    live "/diagrams", Assets.Diagrams
  end

  import Phoenix.LiveDashboard.Router

  pipeline :admin do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :admin_basic_auth
  end

  scope "/dev" do
    pipe_through :admin

    live_dashboard "/dashboard",
      metrics: RetroHexChatWeb.Telemetry,
      metrics_history: {LiveDashboardHistory, :metrics_history, [__MODULE__]},
      ecto_repos: [RetroHexChat.Repo],
      ecto_psql_extras_options: [long_running_queries: [threshold: "500 milliseconds"]],
      additional_pages: [
        app_info: RetroHexChatWeb.Admin.AppInfoPage
      ]
  end

  defp admin_basic_auth(conn, _opts) do
    config = Application.get_env(:retro_hex_chat_web, :basic_auth, [])

    Plug.BasicAuth.basic_auth(conn,
      username: config[:username] || "admin",
      password: config[:password] || "change_me"
    )
  end
end
