defmodule RetroHexChatWeb.Router do
  use RetroHexChatWeb, :router

  @localized_locale_segments RetroHexChatWeb.SEO.localized_locale_segments()
  @showcase_entries RetroHexChatWeb.ShowcaseCatalog.entries()

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :landing_live do
    plug :accepts, ["html"]
    plug :fetch_session
    # The landing pages host the connect window, so they need the same
    # trusted-device context the app pipeline provides.
    plug RetroHexChatWeb.Plugs.PutTrustedDevice
    plug RetroHexChatWeb.Plugs.PutLocale, :public
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :landing_live}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/api", RetroHexChatWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
    get "/calls/healthz", CallsHealthController, :show

    if Application.compile_env(:retro_hex_chat, :e2e_fault_injection?, false) do
      post "/e2e/channel-messages", E2EController, :create_channel_message

      post "/e2e/group-call-peer/terminate",
           E2EFaultController,
           :terminate_group_call_peer
    end
  end

  scope "/", RetroHexChatWeb do
    pipe_through :landing_live

    # The public face of a shared link. On the landing pipeline on purpose:
    # whoever follows one may have no session at all, and the card must not cost
    # them the whole application bundle to find out what they were sent.
    live_session :share_join, on_mount: [{RetroHexChatWeb.Live.PutLocale, :default}] do
      live "/join/:slug", JoinLive
    end

    live_session :landing_locale,
      on_mount: [
        {RetroHexChatWeb.Live.PutLocale, :default},
        {RetroHexChatWeb.Live.PutTrustedDevice, :default}
      ] do
      live "/", LandingLive.Index
      live "/how-it-works", LandingLive.HowItWorks
      live "/features", LandingLive.Features
      live "/privacy", LandingLive.Privacy
      live "/install", LandingLive.Install
      live "/community", LandingLive.Community
      live "/faq", LandingLive.Faq
    end
  end

  for locale_segment <- @localized_locale_segments do
    live_session_name = :"landing_locale_#{String.replace(locale_segment, "-", "_")}"
    join_session_name = :"share_join_#{String.replace(locale_segment, "-", "_")}"

    scope "/#{locale_segment}", RetroHexChatWeb do
      pipe_through :landing_live

      # A share link is a public page, so it exists under every locale segment
      # the public pages do. Registering it only unprefixed is how someone
      # browsing in pt-BR gets a router error instead of the card they were
      # sent — the URL is the one thing about a shared link nobody can fix.
      live_session join_session_name, on_mount: [{RetroHexChatWeb.Live.PutLocale, :default}] do
        live "/join/:slug", JoinLive
      end

      live_session live_session_name,
        on_mount: [
          {RetroHexChatWeb.Live.PutLocale, :default},
          {RetroHexChatWeb.Live.PutTrustedDevice, :default}
        ] do
        live "/", LandingLive.Index
        live "/how-it-works", LandingLive.HowItWorks
        live "/features", LandingLive.Features
        live "/privacy", LandingLive.Privacy
        live "/install", LandingLive.Install
        live "/community", LandingLive.Community
        live "/faq", LandingLive.Faq
      end
    end
  end

  pipeline :help_live do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RetroHexChatWeb.Plugs.PutLocale, :public
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :help_live}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", RetroHexChatWeb do
    pipe_through :help_live

    live_session :help_locale, on_mount: [{RetroHexChatWeb.Live.PutLocale, :default}] do
      live "/chat/help", HelpLive.Index, :index
      live "/chat/help/:topic", HelpLive.Index, :show
    end

    get "/sitemap.xml", SitemapController, :index
    get "/sitemaps/:name", SitemapController, :show
  end

  for locale_segment <- @localized_locale_segments do
    live_session_name = :"help_locale_#{String.replace(locale_segment, "-", "_")}"

    scope "/#{locale_segment}", RetroHexChatWeb do
      pipe_through :help_live

      live_session live_session_name, on_mount: [{RetroHexChatWeb.Live.PutLocale, :default}] do
        live "/chat/help", HelpLive.Index, :index
        live "/chat/help/:topic", HelpLive.Index, :show
      end
    end
  end

  pipeline :chat_session do
    plug RetroHexChatWeb.Plugs.CheckServerBan
  end

  pipeline :app do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RetroHexChatWeb.Plugs.PutTrustedDevice
    plug RetroHexChatWeb.Plugs.PutLocale
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :chat}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", RetroHexChatWeb do
    pipe_through :app

    get "/locale/:locale", LocaleController, :update
  end

  scope "/", RetroHexChatWeb.App do
    pipe_through :app

    get "/chat/scraped-pages/:url_hash/thumbnail", ScrapedPageThumbnailController, :show
    get "/chat/attachments/:id/preview", AttachmentController, :preview
    get "/chat/attachments/:id", AttachmentController, :show

    live_session :app_locale, on_mount: [{RetroHexChatWeb.Live.PutLocale, :default}] do
      live "/connect", ConnectLive
      live "/chat", ChatLive
    end

    # Surfaces that are not the chat. They carry `Live.Surface`, which the chat
    # deliberately does not: it refuses a missing or banned session the same
    # way, and it listens for the end of the session without announcing a
    # takeover. A separate live_session is what lets that on_mount differ.
    live_session :app_surface,
      on_mount: [
        {RetroHexChatWeb.Live.PutLocale, :default},
        {RetroHexChatWeb.Live.PutTrustedDevice, :default},
        {RetroHexChatWeb.Live.Surface, :default}
      ] do
      live "/play", PlayLive
      live "/play/:game", PlayLive
      live "/call/:token", CallLive
      live "/space/:slug", SpaceLive
    end

    # The standalone lobby page is gone — P2P sessions live inside the chat
    # (old invite links and bookmarks land there; the chat re-hydrates the
    # user's active session on mount).
    get "/lobby/:token", LobbyRedirectController, :show
  end

  scope "/", RetroHexChatWeb.App do
    pipe_through [:app, :chat_session]

    post "/chat/session", SessionController, :create
    get "/chat/session/clear", SessionController, :delete
  end

  pipeline :showcase do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RetroHexChatWeb.Plugs.PutLocale
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :showcase}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Every showcase page comes from ShowcaseCatalog — the router does not keep a
  # list of its own. The scope carries no alias because the catalog stores fully
  # qualified page modules.
  scope "/showcase" do
    pipe_through :showcase

    live_session :showcase_locale, on_mount: [{RetroHexChatWeb.Live.PutLocale, :default}] do
      live "/", RetroHexChatWeb.ShowcaseLive.Index

      for entry <- @showcase_entries do
        live "/#{entry.id}", entry.module
      end
    end
  end

  import Phoenix.LiveDashboard.Router

  pipeline :admin do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RetroHexChatWeb.Plugs.PutLocale
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :chat}
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
