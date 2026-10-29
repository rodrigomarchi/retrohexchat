defmodule RetroHexChatWeb.Router do
  use RetroHexChatWeb, :router

  @localized_locale_segments RetroHexChatWeb.SEO.localized_locale_segments()
  @showcase_entries RetroHexChatWeb.ShowcaseCatalog.entries()

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Every public address and every address of the chat is one LiveView on one
  # desktop: the chat runs behind, and a page of the site opens over it as its
  # windows. Moving between them is a patch, never a reload, because
  # they share this one live_session — and the locale segment is part of every
  # address, so the URL decides the language for a visitor and a member alike.
  pipeline :desktop do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RetroHexChatWeb.Plugs.PutTrustedDevice
    plug RetroHexChatWeb.Plugs.PutBrowserId
    plug RetroHexChatWeb.Plugs.PutLocale, :public
    plug RetroHexChatWeb.Plugs.TrustedSignIn
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :desktop}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RetroHexChatWeb.Plugs.RobotsHeader
  end

  # The archive is read by robots that send `If-None-Match`: its conditional
  # answer and its cache headers are decided before the LiveView renders.
  pipeline :archive_http do
    plug RetroHexChatWeb.Plugs.ArchiveConditional
  end

  scope "/api", RetroHexChatWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
    get "/calls/healthz", CallsHealthController, :show

    if Application.compile_env(:retro_hex_chat, :e2e_fault_injection?, false) do
      post "/e2e/channel-messages", E2EController, :create_channel_message
      post "/e2e/contextual-tips/suppress", E2EController, :suppress_contextual_tips
      post "/e2e/game-results", E2EController, :record_game_result
      post "/e2e/arcade-rooms", E2EController, :provision_arcade_rooms

      post "/e2e/group-call-peer/terminate",
           E2EFaultController,
           :terminate_group_call_peer
    end
  end

  live_session :desktop,
    on_mount: [
      {RetroHexChatWeb.Live.PutLocale, :path},
      {RetroHexChatWeb.Live.PutTrustedDevice, :default}
    ] do
    for prefix <- ["/" | Enum.map(@localized_locale_segments, &"/#{&1}")] do
      scope prefix, RetroHexChatWeb do
        pipe_through :desktop

        live "/", DesktopLive, :home
        live "/how-it-works", DesktopLive, :how_it_works
        live "/features", DesktopLive, :features
        live "/privacy", DesktopLive, :privacy
        live "/install", DesktopLive, :install
        live "/community", DesktopLive, :community
        live "/faq", DesktopLive, :faq
        live "/games", DesktopLive, :games
        live "/games/:slug", DesktopLive, :game
        live "/spaces", DesktopLive, :spaces
        live "/paint", DesktopLive, :paint
        live "/ascii-art", DesktopLive, :ascii_art
        live "/radio", DesktopLive, :radio
        live "/mirc-commands", DesktopLive, :mirc_commands
        live "/mirc-online", DesktopLive, :mirc_online
        live "/irc-chat", DesktopLive, :irc_chat
        live "/chat/help", DesktopLive, :help_index
        live "/chat/help/:topic", DesktopLive, :help_topic
        live "/join/:slug", DesktopLive, :join
        live "/connect", DesktopLive, :connect
        # A channel's address. `c` is a reserved first segment, like `archive`
        # and `chat`: none of them may ever be a locale tag.
        live "/c/:channel", DesktopLive, :channel
      end

      scope prefix, RetroHexChatWeb do
        pipe_through [:desktop, :archive_http]

        live "/archive/:channel", DesktopLive, :archive_index
        live "/archive/:channel/:date", DesktopLive, :archive_day
      end
    end
  end

  # A sitemap is XML read by robots, so it takes none of what an HTML page
  # needs: no session to fetch, no CSRF token, no root layout, no browser
  # security headers. It sat on the help pipeline and collected all four. The
  # locale of a list of URLs is meaningless too, which is why `PutLocale`
  # already exempted these paths from its redirect.
  pipeline :sitemap do
    plug :accepts, ["xml"]
  end

  scope "/", RetroHexChatWeb do
    pipe_through :sitemap

    get "/sitemap.xml", SitemapController, :index
    get "/sitemaps/:name", SitemapController, :show
  end

  # The IndexNow key, read back by the engines to verify a list of changed URLs
  # came from this host. Like the sitemap, it is for crawlers: no session, no
  # layout, no locale.
  scope "/", RetroHexChatWeb do
    get "/indexnow.txt", IndexNowController, :key
  end

  # The face of a Space character, beside a nickname in the chat. The address
  # names the picture (catalog version and recipe), so it is cached for good:
  # no session, no layout, nothing that varies by who asks.
  scope "/", RetroHexChatWeb do
    get "/character-portrait/:version/:recipe", CharacterPortraitController, :show
  end

  # The creator's pictures of its pieces — the whole figure, or the head. Only
  # somebody in the chat opens the creator, so only a session gets them drawn.
  scope "/", RetroHexChatWeb do
    pipe_through :app

    get "/character-still/:view/:version/:recipe", CharacterPortraitController, :still
  end

  # The build serving this request, which the deploy polls to confirm the new
  # release is live on every backend.
  scope "/", RetroHexChatWeb do
    get "/version", VersionController, :show
  end

  pipeline :chat_session do
    plug RetroHexChatWeb.Plugs.CheckServerBan
  end

  pipeline :app do
    plug :accepts, ["html"]
    plug :fetch_session
    plug RetroHexChatWeb.Plugs.PutTrustedDevice
    plug RetroHexChatWeb.Plugs.PutBrowserId
    plug RetroHexChatWeb.Plugs.PutLocale
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :surface}
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
    get "/chat/emoji/:id", EmojiController, :show

    # Declared before `/play/:game/:token`, which it would otherwise be read as:
    # `arcade` is a reserved word inside the game namespace, not a game id.
    get "/play/arcade/:game", ArcadeGameController, :show

    # `/chat`, which bookmarks, notifications and share cards still carry:
    # answered with a permanent redirect to the desktop's home or a channel's
    # own address.
    get "/chat", LegacyChatRedirectController, :show

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
      # A match over a P2P session, entered at its game rather than at the
      # console: the address already says which game, so opening on the call
      # section would make the link's own subject a click away. `:game` here is
      # a catalogue id, and `arcade` is not one — the arcade's own route is
      # declared above this one so a game id can never be read as one.
      live "/play/:game/:token", P2PLive
      live "/call/:token", CallLive
      live "/space/:slug", SpaceLive
      live "/p2p/:token", P2PLive
    end

    # Watching a match asks nothing of anyone, an account included, so it is
    # not a surface: `Live.Surface` would send a visitor to sign in first.
    live_session :watch,
      on_mount: [
        {RetroHexChatWeb.Live.PutLocale, :default},
        {RetroHexChatWeb.Live.PutTrustedDevice, :default}
      ] do
      live "/watch/:token", WatchLive
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
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :surface}
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

  # The fallback pair is a development convenience and cannot reach production:
  # `config/runtime.exs` raises at boot there unless both env vars are set, so a
  # release either carries real credentials or does not start.
  defp admin_basic_auth(conn, _opts) do
    config = Application.get_env(:retro_hex_chat_web, :basic_auth, [])

    Plug.BasicAuth.basic_auth(conn,
      username: config[:username] || "admin",
      password: config[:password] || "change_me"
    )
  end
end
