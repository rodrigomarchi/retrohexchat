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

  pipeline :landing do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :landing}
    plug :put_secure_browser_headers
  end

  scope "/api", RetroHexChatWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
  end

  scope "/", RetroHexChatWeb do
    pipe_through :landing

    get "/", LandingController, :index
    get "/about", LandingController, :about
    get "/how-it-works", LandingController, :how_it_works
    get "/features", LandingController, :features
    get "/privacy", LandingController, :privacy
    get "/install", LandingController, :install
    get "/community", LandingController, :community
    get "/faq", LandingController, :faq
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
    live "/button", Button
    live "/input", Input
    live "/label", Label
    live "/textarea", Textarea
    live "/select", Select
    live "/checkbox", Checkbox
    live "/radio-group", RadioGroup
    live "/switch", Switch
    live "/slider", Slider
    live "/toggle", Toggle
    live "/toggle-group", ToggleGroup
    live "/alert", Alert
    live "/badge", Badge
    live "/progress", Progress
    live "/skeleton", Skeleton
    live "/tooltip", Tooltip
    live "/card", Card
    live "/separator", Separator
    live "/tabs", Tabs
    live "/accordion", Accordion
    live "/avatar", Avatar
    live "/table", Table
    live "/icons", Icons
    live "/diagrams", Diagrams
    # Win98 Shell
    live "/window", Window
    live "/menu", MenuPage
    live "/toolbar", ToolbarPage
    live "/status-bar", StatusBar
    # Chat
    live "/irc-tabs", IrcTabsPage
    live "/chat-message", ChatMessagePage
    live "/chat-input", ChatInputPage
    live "/tree-view", TreeViewPage
    live "/nicklist", NicklistPage
    live "/game-cards", GameCardsPage
    live "/fieldset", FieldsetPage
    # Existing components
    live "/dialog", DialogPage
    live "/dropdown-menu", DropdownMenuPage
    live "/breadcrumb", BreadcrumbPage
    live "/pagination", PaginationPage
    live "/toast", ToastPage
    live "/context-menu", ContextMenuPage
    live "/loading-spinner", LoadingSpinnerPage
    live "/empty-state", EmptyStatePage
    live "/color-picker", ColorPickerPage
    live "/scroll-area", ScrollAreaPage
    # Composites
    live "/conversations", ConversationsPage
    live "/hover-card", HoverCardPage
    live "/search-bar", SearchBarPage
    live "/topic-bar", TopicBarPage
    live "/formatting-toolbar", FormattingToolbarPage
    live "/emoji-picker", EmojiPickerPage
    live "/autocomplete", AutocompletePage
    live "/tab-bar", TabBarPage
    live "/reply-bar", ReplyBarPage
    live "/connection-status", ConnectionStatusPage
    # Dialog composites
    live "/confirm-dialog", ConfirmDialogPage
    live "/options-dialog", OptionsDialogPage
    live "/channel-dialog", ChannelDialogPage
    live "/address-book", AddressBookPage
    live "/about-dialog", AboutDialogPage
    live "/channel-list", ChannelListPage
    live "/highlight-dialog", HighlightDialogPage
    live "/config-form", ConfigFormPage
    # Specialized composites
    live "/p2p-lobby", P2PLobbyPage
    live "/media-controls", MediaControlsPage
    live "/file-transfer", FileTransferPage
    live "/chat-layout", ChatLayoutPage
    # New simple components
    live "/scroll-loader", ScrollLoaderPage
    live "/history-search", HistorySearchPage
    live "/kick-dialog", KickDialogPage
    live "/delete-confirm-dialog", DeleteConfirmDialogPage
    live "/disconnect-confirm-dialog", DisconnectConfirmDialogPage
    # New composites (B-02, B-04, B-27)
    live "/status-bar-app", StatusBarAppPage
    live "/conversations-context-menu", ConversationsContextMenuPage
    live "/game-canvas", GameCanvasPage
    # New dialog composites (B-09, B-11, B-12)
    live "/alias-dialog", AliasDialogPage
    live "/flood-protection-dialog", FloodProtectionDialogPage
    live "/ignore-list-dialog", IgnoreListDialogPage
    # New composites (B-07, B-08, B-26)
    live "/notify-list", NotifyListPage
    live "/url-catcher", UrlCatcherPage
    live "/game-lobby", GameLobbyPage
    # New dialog composites (B-10, B-13, B-15)
    live "/auto-respond-dialog", AutoRespondDialogPage
    live "/custom-menus-dialog", CustomMenusDialogPage
    live "/sound-settings-dialog", SoundSettingsDialogPage
    # New simple components (B-18, B-21, B-29, B-30)
    live "/invite-dialog", InviteDialogPage
    live "/paste-confirm-dialog", PasteConfirmDialogPage
    live "/arcade-frame", ArcadeFramePage
    live "/app-header", AppHeaderPage
    # New medium components (B-14, B-22, B-16, B-23)
    live "/ctcp-settings-dialog", CtcpSettingsDialogPage
    live "/cheatsheet-dialog", CheatsheetDialogPage
    live "/nick-change-dialog", NickChangeDialogPage
    live "/syntax-tooltip", SyntaxTooltipPage
    # New large components (B-01, B-03, B-05, B-06, B-28)
    live "/toolbar-app", ToolbarAppPage
    live "/solo-lobby", SoloLobbyPage
    live "/chat-context-menu", ChatContextMenuPage
    live "/perform-dialog", PerformDialogPage
    live "/channel-central-dialog", ChannelCentralDialogPage
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
