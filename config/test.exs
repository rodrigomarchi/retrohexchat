import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :retro_hex_chat, RetroHexChat.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5433")),
  database: "retro_hex_chat_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_only_secret_key_base_not_for_production_run_mix_phx_gen_secret_to_replace",
  server: false

# Silence all logs during test (use @tag :capture_log to inspect per-test)
config :logger, level: :none

# Configure bcrypt with reduced rounds for fast tests
config :bcrypt_elixir, log_rounds: 4

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Server roles — admin and operator nicknames for tests
config :retro_hex_chat,
  admins: ["TestAdmin"],
  server_operators: ["TestOper"]

# TURN server test overrides — disable listener, use random port, fixed secrets
config :retro_hex_chat,
  turn_listen_port: 0,
  turn_listener_count: 0,
  turn_auth_secret: "test-auth-secret-64-bytes-long-padding-padding-padding-padding-pad",
  turn_nonce_secret: "test-nonce-secret-64-bytes-long-padding-padding-padding-padding-pad",
  # P2P rate limiting — small windows for fast tests
  p2p_session_rate_limit: {5, 1_000},
  signaling_rate_limiter: RetroHexChat.P2P.SignalingRateLimit.Noop

# Basic auth for LiveDashboard
config :retro_hex_chat_web, :basic_auth, username: "admin", password: "test"
