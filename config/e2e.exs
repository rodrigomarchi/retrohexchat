import Config

# Dedicated MIX_ENV for the browser-driven Playwright suite under top-level
# e2e/. Inherits patterns from config/test.exs but with two critical differences:
#
#   1. server: true — the HTTP server must actually run so a real browser can
#      hit it (otherwise LiveView never mounts).
#   2. No Ecto SQL Sandbox — the Playwright process and the Phoenix server are
#      two separate BEAMs; a sandbox would isolate them from each other.
#
# A dedicated database (retro_hex_chat_e2e) keeps this env from polluting
# test or dev state. The server listens on port 4003 to avoid colliding with
# dev (4000) and test endpoint config (4002).
config :retro_hex_chat, RetroHexChat.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5433")),
  database: "retro_hex_chat_e2e",
  pool_size: 10

config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base:
    "e2e_only_secret_key_base_not_for_production_run_mix_phx_gen_secret_to_replace",
  server: true,
  check_origin: false,
  debug_errors: true

# Quiet logs by default so Playwright output is readable; override via LOG_LEVEL.
config :logger, level: String.to_atom(System.get_env("LOG_LEVEL", "warning"))

# Reduced bcrypt rounds so registration is fast in browser tests.
config :bcrypt_elixir, log_rounds: 4

# Faster runtime plug compilation (same as test).
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Server roles — mirror test config so e2e specs can rely on them.
config :retro_hex_chat,
  admins: ["TestAdmin"],
  server_operators: ["TestOper"]

# TURN server — disabled in e2e (no WebRTC specs yet); same secret shape as test.
config :retro_hex_chat,
  turn_listen_port: 0,
  turn_listener_count: 0,
  turn_auth_secret: "e2e-auth-secret-64-bytes-long-padding-padding-padding-padding-padd",
  turn_nonce_secret: "e2e-nonce-secret-64-bytes-long-padding-padding-padding-padding-pad",
  p2p_session_rate_limit: {5, 1_000},
  signaling_rate_limiter: RetroHexChat.P2P.SignalingRateLimit.Noop

# Basic auth for LiveDashboard
config :retro_hex_chat_web, :basic_auth, username: "admin", password: "e2e"
