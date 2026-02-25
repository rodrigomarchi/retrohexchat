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
  end

  scope "/", RetroHexChatWeb do
    pipe_through [:browser, :chat_session]

    post "/chat/session", SessionController, :create
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
