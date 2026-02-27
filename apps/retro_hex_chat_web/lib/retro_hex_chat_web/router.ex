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
