import Config

# Plausible analytics environment label, surfaced to the browser via a
# <meta name="plausible-env"> tag in root.html.heex. The bundled tracker
# attaches it as a `env` prop to every event so the same Plausible site
# can serve both staging and production.
config :retro_hex_chat_web, :plausible_env, System.get_env("APP_ENV", "prod")

config :retro_hex_chat_web,
  public_origin: System.get_env("PUBLIC_ORIGIN") || "https://retrohexchat.app"

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Default channel (all environments)
config :retro_hex_chat,
  default_channel: System.get_env("DEFAULT_CHANNEL") || "#lobby"

# Base URL for generating links in domain layer (bots, etc.)
config :retro_hex_chat,
  base_url: System.get_env("BASE_URL") || "http://localhost:4000"

# Base URL for the Solo Arcade WASM game assets. Games are served from
# an external static host (built and published from the retro-wasm-builder
# repo); the application never bundles or serves them locally.
# Each game's URL is composed as `${arcade_base_url}/${game_id}/index.html`.
config :retro_hex_chat,
  arcade_base_url: System.get_env("ARCADE_BASE_URL") || "https://static.retrohexchat.app/arcade"

# TURN server runtime config (all environments)
config :retro_hex_chat,
  turn_listen_ip: {0, 0, 0, 0},
  turn_listen_port: 3478,
  turn_relay_ip:
    (case System.get_env("TURN_RELAY_IP") do
       nil -> :auto
       ip_str -> ip_str |> to_charlist() |> :inet.parse_address() |> elem(1)
     end),
  turn_relay_port_range:
    {String.to_integer(System.get_env("TURN_RELAY_PORT_MIN") || "49152"),
     String.to_integer(System.get_env("TURN_RELAY_PORT_MAX") || "49651")},
  turn_listener_count: System.schedulers_online(),
  turn_auth_secret:
    (case System.get_env("TURN_SECRET") do
       nil -> :crypto.strong_rand_bytes(64)
       secret -> secret
     end),
  turn_nonce_secret:
    (case System.get_env("TURN_NONCE_SECRET") do
       nil -> :crypto.strong_rand_bytes(64)
       secret -> secret
     end)

# Root admins (all environments) — immutable, cannot be removed via /admin commands
config :retro_hex_chat,
  root_admins:
    (System.get_env("ROOT_ADMINS") || "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)

# File transfer runtime config (all environments)
config :retro_hex_chat,
  file_transfer_max_size_mb:
    String.to_integer(System.get_env("FILE_TRANSFER_MAX_SIZE_MB") || "500"),
  file_transfer_blocked_extensions:
    (System.get_env("FILE_TRANSFER_BLOCKED_EXTENSIONS") ||
       ".exe,.bat,.cmd,.com,.msi,.scr,.pif,.vbs,.vbe,.js,.jse,.wsf,.wsh,.ps1,.reg")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1),
  file_transfer_chunk_size_kb:
    String.to_integer(System.get_env("FILE_TRANSFER_CHUNK_SIZE_KB") || "64")

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :retro_hex_chat, RetroHexChat.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "retrohexchat.app"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip:
        if(System.get_env("ECTO_IPV6") in ~w(true 1),
          do: {0, 0, 0, 0, 0, 0, 0, 0},
          else: {0, 0, 0, 0}
        ),
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true,
    check_origin: ["https://#{host}"]

  # Override base_url for production
  config :retro_hex_chat, base_url: "https://#{host}"

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :retro_hex_chat_web, RetroHexChatWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :retro_hex_chat, RetroHexChat.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  config :retro_hex_chat, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :retro_hex_chat_web, :basic_auth,
    username: System.get_env("DASHBOARD_USER") || raise("DASHBOARD_USER env var is required"),
    password:
      System.get_env("DASHBOARD_PASSWORD") || raise("DASHBOARD_PASSWORD env var is required")
end
