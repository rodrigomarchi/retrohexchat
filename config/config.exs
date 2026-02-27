# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :retro_hex_chat,
  ecto_repos: [RetroHexChat.Repo],
  admins: [],
  server_operators: [],
  p2p_token_secret: "p2p-dev-secret-key-base-at-least-64-bytes-long-for-phoenix-token-signing",
  # TURN server compile-time config
  turn_realm: "retro-hex-chat",
  turn_credentials_lifetime: 3_600,
  turn_nonce_lifetime: 3_600_000_000_000,
  turn_default_allocation_lifetime: 600,
  turn_max_allocation_lifetime: 3_600,
  turn_permission_lifetime: 300,
  turn_channel_lifetime: 600,
  # P2P rate limiting
  p2p_session_rate_limit: {5, 600_000},
  signaling_rate_limiter: RetroHexChat.P2P.SignalingRateLimit.ETS

config :retro_hex_chat_web,
  ecto_repos: [RetroHexChat.Repo],
  generators: [context_app: :retro_hex_chat]

# Configures the endpoint
config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RetroHexChatWeb.ErrorHTML, json: RetroHexChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RetroHexChat.PubSub,
  live_view: [signing_salt: "tFc/qS/G"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  retro_hex_chat_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/retro_hex_chat_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  retro_hex_chat_web_css: [
    args:
      ~w(css/app.css --bundle --target=es2022 --outdir=../priv/static/assets/css --loader:.woff=file --loader:.woff2=file),
    cd: Path.expand("../apps/retro_hex_chat_web/assets", __DIR__),
    env: %{}
  ],
  retro_hex_chat_web_landing: [
    args:
      ~w(js/landing.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/retro_hex_chat_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  retro_hex_chat_web_landing_css: [
    args:
      ~w(css/pages/landing.css --bundle --target=es2022 --outdir=../priv/static/assets/css --loader:.woff=file --loader:.woff2=file),
    cd: Path.expand("../apps/retro_hex_chat_web/assets", __DIR__),
    env: %{}
  ],
  retro_hex_chat_web_showcase_js: [
    args:
      ~w(js/showcase.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/retro_hex_chat_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Metrics history for LiveDashboard
config :live_dashboard_history, LiveDashboardHistory,
  router: RetroHexChatWeb.Router,
  metrics: RetroHexChatWeb.Telemetry

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use Tz for timezone database (compile-time, no GenServer)
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
