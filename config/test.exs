import Config

test_http_port = String.to_integer(System.get_env("TEST_PORT", "4002"))
test_database_suffix = System.get_env("TEST_DB_SUFFIX") || System.get_env("MIX_TEST_PARTITION")

test_database_pool_size =
  case Integer.parse(System.get_env("TEST_DB_POOL_SIZE", "")) do
    {pool_size, ""} when pool_size > 0 -> pool_size
    _ -> System.schedulers_online() * 2
  end

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# TEST_DB_SUFFIX lets the local CI runner use distinct databases for separate
# test groups that are partitioned independently.
# Run `mix help test` for more information.
config :retro_hex_chat, RetroHexChat.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5433")),
  database: "retro_hex_chat_test#{test_database_suffix}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: test_database_pool_size

config :retro_hex_chat, Oban,
  engine: Oban.Engines.Basic,
  repo: RetroHexChat.Repo,
  testing: :manual,
  queues: false,
  plugins: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: test_http_port],
  secret_key_base:
    "test_only_secret_key_base_not_for_production_run_mix_phx_gen_secret_to_replace",
  server: false

# Silence all logs during test (use @tag :capture_log to inspect per-test)
config :logger, level: :none

# Configure bcrypt with reduced rounds for fast tests
config :bcrypt_elixir, log_rounds: 4

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :opentelemetry, traces_exporter: :none

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Server roles — admin and operator nicknames for tests
config :retro_hex_chat,
  admins: ["TestAdmin"],
  server_operators: ["TestOper"],
  # Bot authorization asks whether a nickname is identified. Answering it for
  # real means a NickServ registration and a bcrypt hash per case, which is not
  # what those tests are about — the stub says yes and the `admins` list above
  # stays the thing under test.
  bot_identity: RetroHexChat.Bots.IdentityStub

# TURN server test overrides — disable listener, use random port, fixed secrets
config :retro_hex_chat,
  turn_listen_port: 0,
  turn_listener_count: 0,
  turn_auth_secret: "test-auth-secret-64-bytes-long-padding-padding-padding-padding-pad",
  turn_nonce_secret: "test-nonce-secret-64-bytes-long-padding-padding-padding-padding-pad",
  # P2P rate limiting — small windows for fast tests
  p2p_session_rate_limit: {5, 1_000},
  signaling_rate_limiter: RetroHexChat.P2P.SignalingRateLimit.Noop,
  # Group-call rate limiting — high enough not to interfere except in focused tests
  group_call_create_rate_limit: {100, 1_000},
  group_call_join_rate_limit: {100, 1_000},
  group_call_signal_rate_limit: {1_000, 1_000}

# Basic auth for LiveDashboard
config :retro_hex_chat_web, :basic_auth, username: "admin", password: "test"
